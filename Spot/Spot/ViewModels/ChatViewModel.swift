//
//  ChatViewModel.swift
//  Spot
//
//  ViewModel managing the chat conversation state.
//  Orchestrates messages, LLM calls, and workout services.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@available(iOS 26.0, *)
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var activeSession: WorkoutSession?
    @Published var showQuickActions: Bool = true
    @Published var streamingResponse: String = ""
    @Published var currentConversation: Conversation?
    
    // Track exercise state for detecting new logged sets
    private var previousExerciseSetCounts: [String: Int] = [:]
    private var previousExerciseMaxWeights: [String: Double] = [:]
    
    /// Check if the current streaming response appears to be a logging confirmation
    var isLoggingResponse: Bool {
        let response = streamingResponse.lowercased()
        return response.contains("logged:") ||
               response.contains("logged!") ||
               response.contains("got it!") ||
               response.contains("nice work!") ||
               response.contains("updated:") ||
               response.contains("deleted") ||
               response.contains("removed")
    }
    
    // MARK: - Services
    
    private let modelContext: ModelContext
    private let workoutService: WorkoutService
    private var llmService: LLMService?
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.workoutService = WorkoutService(modelContext: modelContext)
        
        // Clean up stale sessions (older than 12 hours)
        cleanupStaleSessions()
        
        // Check for active workout session
        activeSession = workoutService.getActiveSession()
        
        // Load or create conversation
        loadActiveConversation()
        
        // Initialize LLM service
        initializeLLMService()
    }
    
    // MARK: - Cleanup
    
    /// Mark sessions older than 4 hours as inactive, or empty sessions
    private func cleanupStaleSessions() {
        let staleThreshold = Date().addingTimeInterval(-4 * 60 * 60) // 4 hours ago
        
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.endTime == nil
            }
        )
        
        if let activeSessions = try? modelContext.fetch(descriptor) {
            for session in activeSessions {
                // Mark as ended if older than threshold OR has no exercises
                if session.startTime < staleThreshold || session.exercises.isEmpty {
                    session.endTime = Date()
                }
            }
        }
        
        // Also clean up stale conversations
        let conversationDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.isActive }
        )
        
        if let activeConversations = try? modelContext.fetch(conversationDescriptor) {
            for conversation in activeConversations {
                // Mark general chats older than 4 hours as inactive
                if conversation.linkedSession == nil && conversation.lastMessageAt < staleThreshold {
                    conversation.isActive = false
                }
                // Mark workout conversations as inactive if their session is ended
                if let session = conversation.linkedSession, !session.isActive {
                    conversation.isActive = false
                }
                // Mark conversations with no messages as inactive
                if conversation.messages.isEmpty {
                    conversation.isActive = false
                }
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - LLM Initialization
    
    private func initializeLLMService() {
        do {
            llmService = try LLMService(
                modelContext: modelContext,
                workoutService: workoutService
            )
            // Pre-warm the model for faster first response
            llmService?.prewarm()
        } catch {
            print("Failed to initialize LLM service: \(error)")
        }
    }
    
    // MARK: - Conversation Management
    
    /// Load the most recent active conversation or start fresh
    private func loadActiveConversation() {
        // Only load a conversation if it has an active workout session
        // This prevents loading stale general chats from previous sessions
        if let session = activeSession, session.isActive {
            // Find the conversation linked to this active session
            let descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.isActive },
                sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
            )
            
            if let conversations = try? modelContext.fetch(descriptor),
               let active = conversations.first(where: { $0.linkedSession?.id == session.id }) {
                currentConversation = active
                loadMessages(for: active)
                return
            }
        }
        
        // No active workout - start fresh (don't load old general chats)
        currentConversation = nil
        messages = []
        showQuickActions = true
    }
    
    /// Load messages for a specific conversation
    func loadMessages(for conversation: Conversation) {
        messages = conversation.orderedMessages
        showQuickActions = messages.isEmpty
    }
    
    /// Switch to a different conversation
    func switchToConversation(_ conversation: Conversation) {
        // Mark previous conversation as inactive if it has no active workout
        if let current = currentConversation,
           current.id != conversation.id,
           !(current.linkedSession?.isActive ?? false) {
            current.isActive = false
        }
        
        // Reset LLM session to clear context from previous conversation
        llmService?.resetSession()
        
        currentConversation = conversation
        conversation.isActive = true
        loadMessages(for: conversation)
        
        // Update active session to the conversation's linked session
        // This ensures the header shows the correct workout title
        activeSession = conversation.linkedSession
    }
    
    /// Start a new conversation
    func startNewConversation() {
        // End any active workout session
        if let session = activeSession {
            workoutService.endSession(session)
        }
        
        // Mark current conversation as inactive
        if let current = currentConversation {
            current.isActive = false
        }
        
        // Save changes so they persist in history
        try? modelContext.save()
        
        // Reset LLM session for fresh context
        llmService?.resetSession()
        
        // Reset to fresh state
        currentConversation = nil
        activeSession = nil
        messages = []
        showQuickActions = true
    }
    
    /// Create or get the current conversation
    private func ensureConversation() -> Conversation {
        if let existing = currentConversation {
            return existing
        }
        
        // Create new conversation
        let conversation = Conversation(title: "New Chat", type: .general)
        modelContext.insert(conversation)
        currentConversation = conversation
        return conversation
    }
    
    // MARK: - Workout Session Handling
    
    /// Called when the LLM starts a workout session
    func handleWorkoutStarted(session: WorkoutSession) {
        activeSession = session
        
        // Convert current conversation to workout type
        if let conversation = currentConversation {
            conversation.convertToWorkout(session: session)
        }
    }
    
    // MARK: - Streaming Message
    
    func sendMessageStreaming() async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Clear input immediately
        inputText = ""
        showQuickActions = false
        streamingResponse = ""
        
        // Capture exercise state before processing
        captureExerciseState()
        
        // Ensure we have a conversation
        let conversation = ensureConversation()
        
        // Add user message
        let userMessage = ChatMessage(
            content: trimmedText,
            role: .user,
            conversation: conversation
        )
        messages.append(userMessage)
        modelContext.insert(userMessage)
        conversation.messages.append(userMessage)
        conversation.touchLastMessage()
        
        // Auto-generate title for general chats on first message
        if conversation.type == .general && conversation.messages.count == 1 {
            conversation.autoGenerateTitle()
        }
        
        // Show loading state
        isLoading = true
        
        guard let llmService = llmService else {
            let errorMessage = ChatMessage(
                content: "AI service not available.",
                role: .assistant,
                conversation: conversation
            )
            messages.append(errorMessage)
            modelContext.insert(errorMessage)
            conversation.messages.append(errorMessage)
            isLoading = false
            return
        }
        
        do {
            let finalResponse = try await llmService.streamResponse(
                userMessage: trimmedText,
                conversationHistory: messages
            ) { [weak self] partial in
                Task { @MainActor in
                    // Filter out "null" responses and tool call JSON from streaming
                    let cleaned = partial.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned != "null" && !cleaned.isEmpty {
                        // Filter out raw tool call JSON (e.g., {"name": "...", "arguments": {...}})
                        if !cleaned.hasPrefix("{") || !cleaned.contains("\"name\"") || !cleaned.contains("\"arguments\"") {
                            self?.streamingResponse = partial
                        }
                    }
                }
            }
            
            // Update active session state first to get latest exercises
            if let currentSession = workoutService.getActiveSession() {
                activeSession = currentSession
            }
            
            // Detect if an exercise was logged
            let loggedExerciseInfo = detectLoggedExercise()
            
            // Clean final response - remove any tool call JSON that might have leaked through
            var cleanedResponse = finalResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            // Filter out raw tool call JSON patterns
            if cleanedResponse.hasPrefix("{") && cleanedResponse.contains("\"name\"") && cleanedResponse.contains("\"arguments\"") {
                // This looks like a tool call JSON - try to extract a meaningful response
                // If it's a log_workout_session, provide a friendly message
                if cleanedResponse.contains("log_workout_session") {
                    cleanedResponse = "Got it! What are we hitting today?"
                } else {
                    // For other tool calls, use a generic friendly response
                    cleanedResponse = "Got it!"
                }
            }
            
            // Add final assistant message
            let assistantMessage = ChatMessage(
                content: cleanedResponse,
                role: .assistant,
                conversation: conversation
            )
            
            // Attach logged exercise info if present
            if let info = loggedExerciseInfo {
                assistantMessage.loggedExerciseInfo = info
            }
            
            messages.append(assistantMessage)
            modelContext.insert(assistantMessage)
            conversation.messages.append(assistantMessage)
            conversation.touchLastMessage()
            
            // Re-update active session state
            activeSession = workoutService.getActiveSession()
            
            // Check if any sets were edited and update logged exercise cards
            updateLoggedExerciseCardsForEdits()
            
            // If a session was started, update the conversation
            if let session = activeSession,
               conversation.linkedSession == nil {
                conversation.convertToWorkout(session: session)
            }
            
            // Save conversation to persist in history
            try? modelContext.save()
            
            // Trigger UI refresh for header
            objectWillChange.send()
            
        } catch {
            let errorMessage = ChatMessage(
                content: "Oops, something went wrong. Try again?",
                role: .assistant,
                conversation: conversation
            )
            messages.append(errorMessage)
            modelContext.insert(errorMessage)
            conversation.messages.append(errorMessage)
            print("LLM Error: \(error)")
        }
        
        isLoading = false
        streamingResponse = ""
    }
    
    // MARK: - Legacy Send Message (non-streaming)
    
    func sendMessage() async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Clear input immediately
        inputText = ""
        showQuickActions = false
        streamingResponse = ""
        
        // Ensure we have a conversation
        let conversation = ensureConversation()
        
        // Add user message
        let userMessage = ChatMessage(
            content: trimmedText,
            role: .user,
            conversation: conversation
        )
        messages.append(userMessage)
        modelContext.insert(userMessage)
        conversation.messages.append(userMessage)
        conversation.touchLastMessage()
        
        // Auto-generate title for general chats on first message
        if conversation.type == .general && conversation.messages.count == 1 {
            conversation.autoGenerateTitle()
        }
        
        // Show loading state
        isLoading = true
        
        // Generate response
        do {
            var response = try await generateResponse(for: trimmedText)
            
            // Clean response - remove any tool call JSON that might have leaked through
            let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("{") && cleaned.contains("\"name\"") && cleaned.contains("\"arguments\"") {
                // This looks like a tool call JSON - provide a friendly response
                if cleaned.contains("log_workout_session") {
                    response = "Got it! What are we hitting today?"
                } else {
                    response = "Got it!"
                }
            }
            
            // Add assistant message
            let assistantMessage = ChatMessage(
                content: response,
                role: .assistant,
                conversation: conversation
            )
            messages.append(assistantMessage)
            modelContext.insert(assistantMessage)
            conversation.messages.append(assistantMessage)
            conversation.touchLastMessage()
            
            // Update active session state
            activeSession = workoutService.getActiveSession()
            
        } catch {
            // Handle error with a friendly message
            let errorMessage = ChatMessage(
                content: "Oops, something went wrong. Try again?",
                role: .assistant,
                conversation: conversation
            )
            messages.append(errorMessage)
            modelContext.insert(errorMessage)
            conversation.messages.append(errorMessage)
            print("LLM Error: \(error)")
        }
        
        isLoading = false
        streamingResponse = ""
    }
    
    // MARK: - Response Generation
    
    private func generateResponse(for input: String) async throws -> String {
        guard let llmService = llmService else {
            throw LLMError.notAvailable
        }
        
        return try await llmService.generateResponse(
            userMessage: input,
            conversationHistory: messages
        )
    }
    
    // MARK: - Session Management
    
    func endWorkout() {
        guard let session = activeSession else { return }
        workoutService.endSession(session)
        activeSession = nil
        
        // Mark conversation as inactive
        if let conversation = currentConversation {
            conversation.isActive = false
        }
        
        showQuickActions = true
    }
    
    // MARK: - Session Summary
    
    func generateSessionSummary(_ session: WorkoutSession) -> String {
        let exercises = session.exercises.count
        let sets = session.totalSets
        
        if exercises == 0 {
            return "No exercises logged."
        }
        
        var summary = "You did \(exercises) exercise\(exercises == 1 ? "" : "s") with \(sets) total sets."
        
        // Check for PRs
        let prCount = session.exercises.reduce(0) { $0 + ($1.hasPR ? 1 : 0) }
        if prCount > 0 {
            summary += " You hit \(prCount) PR\(prCount == 1 ? "" : "s")!"
        }
        
        return summary
    }
    
    // MARK: - Clear Chat
    
    func clearChat() {
        startNewConversation()
    }
    
    // MARK: - Exercise Logging Detection
    
    /// Capture current exercise state before sending a message
    private func captureExerciseState() {
        previousExerciseSetCounts = [:]
        previousExerciseMaxWeights = [:]
        
        // Capture set counts from current session
        if let session = activeSession ?? workoutService.getActiveSession() {
            for workoutExercise in session.exercises {
                if let exercise = workoutExercise.exercise {
                    previousExerciseSetCounts[exercise.name] = workoutExercise.sets.count
                    // Use the MAX of allTimeMaxWeight and current session's max weight
                    // This ensures manual weight edits in the current session are captured
                    let allTimeMax = exercise.allTimeMaxWeight ?? 0
                    let sessionMax = workoutExercise.orderedSets.map(\.weight).max() ?? 0
                    previousExerciseMaxWeights[exercise.name] = max(allTimeMax, sessionMax)
                }
            }
        }
        
        // Also capture max weights for ALL known exercises (for new exercises added this session)
        let descriptor = FetchDescriptor<Exercise>()
        if let allExercises = try? modelContext.fetch(descriptor) {
            for exercise in allExercises {
                if previousExerciseMaxWeights[exercise.name] == nil {
                    previousExerciseMaxWeights[exercise.name] = exercise.allTimeMaxWeight ?? 0
                }
            }
        }
    }
    
    /// Detect all exercises that had new sets logged and build LoggedExerciseInfo
    private func detectLoggedExercise() -> LoggedExerciseInfo? {
        guard let session = activeSession ?? workoutService.getActiveSession() else { return nil }
        
        var loggedExercises: [LoggedExerciseInfo.ExerciseEntry] = []
        
        // Find all exercises with new sets
        for workoutExercise in session.exercises {
            guard let exercise = workoutExercise.exercise else { continue }
            let exerciseName = exercise.name
            let currentSetCount = workoutExercise.sets.count
            let previousCount = previousExerciseSetCounts[exerciseName] ?? 0
            
            // This exercise has new sets (or is a new exercise with sets)
            // Check if sets were added OR if this is a new exercise that wasn't tracked before
            if currentSetCount > previousCount || (currentSetCount > 0 && previousCount == 0 && !previousExerciseSetCounts.keys.contains(exerciseName)) {
                let orderedSets = workoutExercise.orderedSets
                let hasPR = orderedSets.contains { $0.isPR }
                
                // Build the logged sets info - only include NEW sets if we can determine which ones
                // For simplicity, include all sets if this is a new exercise or if we can't determine
                let setInfos: [LoggedExerciseInfo.LoggedSetInfo] = orderedSets.map { set in
                    LoggedExerciseInfo.LoggedSetInfo(
                        setNumber: set.setNumber,
                        weight: set.weight,
                        reps: set.reps,
                        isPR: set.isPR
                    )
                }
                
                // Get the previous best weight (captured before the message was sent)
                let previousBest = previousExerciseMaxWeights[exerciseName]
                
                loggedExercises.append(LoggedExerciseInfo.ExerciseEntry(
                    exerciseName: exerciseName,
                    sets: setInfos,
                    isPR: hasPR,
                    previousBest: (hasPR && previousBest != nil && previousBest! > 0) ? previousBest : nil
                ))
            }
        }
        
        // Return nil if no exercises were logged
        guard !loggedExercises.isEmpty else { return nil }
        
        return LoggedExerciseInfo(exercises: loggedExercises)
    }
    
    /// Update logged exercise cards in messages when sets are edited
    /// This refreshes the cards to reflect current session state after edits
    private func updateLoggedExerciseCardsForEdits() {
        guard let session = activeSession ?? workoutService.getActiveSession() else { return }
        
        // Check if the last assistant message suggests an edit occurred
        guard let lastContent = messages.last?.content.lowercased() else { return }
        
        // Detect if this was an edit operation
        let isEditOperation = lastContent.contains("updated") ||
                             lastContent.contains("changed") ||
                             lastContent.contains("adjusted") ||
                             lastContent.contains("edited") ||
                             lastContent.contains("fixed")
        
        if !isEditOperation {
            return
        }
        
        // Update all messages that have logged exercise info
        for message in messages where message.isAssistant {
            guard let loggedInfo = message.loggedExerciseInfo else { continue }
            
            var updatedExercises: [LoggedExerciseInfo.ExerciseEntry] = []
            
            // Rebuild exercise entries from current session state
            for exerciseEntry in loggedInfo.exercises {
                // Find the exercise in the current session
                guard let workoutExercise = session.exercises.first(where: { 
                    $0.exercise?.name == exerciseEntry.exerciseName 
                }),
                let exercise = workoutExercise.exercise else {
                    // Exercise not found, keep original entry
                    updatedExercises.append(exerciseEntry)
                    continue
                }
                
                let orderedSets = workoutExercise.orderedSets
                let updatedSetInfos: [LoggedExerciseInfo.LoggedSetInfo] = orderedSets.map { set in
                    LoggedExerciseInfo.LoggedSetInfo(
                        setNumber: set.setNumber,
                        weight: set.weight,
                        reps: set.reps,
                        isPR: set.isPR
                    )
                }
                
                let hasPR = orderedSets.contains { $0.isPR }
                let previousBest = previousExerciseMaxWeights[exercise.name]
                
                updatedExercises.append(LoggedExerciseInfo.ExerciseEntry(
                    exerciseName: exercise.name,
                    sets: updatedSetInfos,
                    isPR: hasPR,
                    previousBest: (hasPR && previousBest != nil && previousBest! > 0) ? previousBest : nil
                ))
            }
            
            // Update the message if anything changed
            let updatedInfo = LoggedExerciseInfo(exercises: updatedExercises)
            if updatedInfo != loggedInfo {
                message.loggedExerciseInfo = updatedInfo
            }
        }
        
        // Trigger UI update
        objectWillChange.send()
    }
    
    // MARK: - Exercise Editing from UI
    
    /// Update an exercise from the edit sheet UI
    func updateExercise(
        originalName: String,
        newName: String,
        updatedSets: [(weight: Double, reps: Int)]
    ) -> Bool {
        let success = workoutService.updateExerciseFromEdit(
            exerciseName: originalName,
            newExerciseName: newName,
            updatedSets: updatedSets
        )
        
        if success {
            // Update the logged exercise cards in messages
            refreshLoggedExerciseCards()
            objectWillChange.send()
        }
        
        return success
    }
    
    /// Reload messages for the current conversation
    func reloadCurrentMessages() {
        if let conversation = currentConversation {
            loadMessages(for: conversation)
        }
        refreshLoggedExerciseCards()
        objectWillChange.send()
    }
    
    /// Refresh all logged exercise cards to reflect current session state
    private func refreshLoggedExerciseCards() {
        guard let session = activeSession ?? workoutService.getActiveSession() else { return }
        
        for message in messages where message.isAssistant {
            guard let loggedInfo = message.loggedExerciseInfo else { continue }
            
            var updatedExercises: [LoggedExerciseInfo.ExerciseEntry] = []
            
            for exerciseEntry in loggedInfo.exercises {
                // Find the exercise in the current session
                guard let workoutExercise = session.exercises.first(where: { 
                    $0.exercise?.name.lowercased() == exerciseEntry.exerciseName.lowercased() 
                }),
                let exercise = workoutExercise.exercise else {
                    // Try to find by matching renamed exercise
                    if let workoutExercise = session.exercises.first(where: { we in
                        we.orderedSets.count == exerciseEntry.sets.count
                    }),
                    let exercise = workoutExercise.exercise {
                        // This might be the renamed exercise
                        let orderedSets = workoutExercise.orderedSets
                        let updatedSetInfos: [LoggedExerciseInfo.LoggedSetInfo] = orderedSets.map { set in
                            LoggedExerciseInfo.LoggedSetInfo(
                                setNumber: set.setNumber,
                                weight: set.weight,
                                reps: set.reps,
                                isPR: set.isPR
                            )
                        }
                        
                        let hasPR = orderedSets.contains { $0.isPR }
                        
                        updatedExercises.append(LoggedExerciseInfo.ExerciseEntry(
                            exerciseName: exercise.name,
                            sets: updatedSetInfos,
                            isPR: hasPR,
                            previousBest: exerciseEntry.previousBest
                        ))
                        continue
                    }
                    
                    // Exercise not found, keep original entry
                    updatedExercises.append(exerciseEntry)
                    continue
                }
                
                let orderedSets = workoutExercise.orderedSets
                let updatedSetInfos: [LoggedExerciseInfo.LoggedSetInfo] = orderedSets.map { set in
                    LoggedExerciseInfo.LoggedSetInfo(
                        setNumber: set.setNumber,
                        weight: set.weight,
                        reps: set.reps,
                        isPR: set.isPR
                    )
                }
                
                let hasPR = orderedSets.contains { $0.isPR }
                
                updatedExercises.append(LoggedExerciseInfo.ExerciseEntry(
                    exerciseName: exercise.name,
                    sets: updatedSetInfos,
                    isPR: hasPR,
                    previousBest: exerciseEntry.previousBest
                ))
            }
            
            // Update the message
            let updatedInfo = LoggedExerciseInfo(exercises: updatedExercises)
            message.loggedExerciseInfo = updatedInfo
        }
        
        try? modelContext.save()
    }
}
