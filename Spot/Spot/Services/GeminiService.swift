//
//  GeminiService.swift
//  Spot
//
//  Service for interacting with Google Gemini API.
//  Conforms to AIService protocol for the Strategy Pattern.
//
//  NOTE: To upgrade to a newer model, change modelName to "gemini-3-flash"
//

import Foundation
import GoogleGenerativeAI

/// Errors specific to Gemini service
enum GeminiError: Error, LocalizedError {
    case invalidAPIKey
    case functionCallFailed(String)
    case noResponse
    case rateLimited(retryAfter: TimeInterval?)
    case contentFiltered
    case emptyResponse
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid Gemini API key. Please check Secrets.swift"
        case .functionCallFailed(let message):
            return "Function call failed: \(message)"
        case .noResponse:
            return "No response from Gemini"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please try again in \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again in a moment."
        case .contentFiltered:
            return "Response was filtered. Please try rephrasing your message."
        case .emptyResponse:
            return "Received an empty response. Please try again."
        case .maxRetriesExceeded:
            return "Service temporarily unavailable. Please try again later."
        }
    }
}

/// AI service using Google Gemini 2.5 Flash
@available(iOS 26.0, *)
@MainActor
class GeminiService: AIService {
    private let workoutService: WorkoutService
    private let model: GenerativeModel
    
    /// Manual history tracking - avoids SDK parsing issues with Chat object
    private var conversationHistory: [ModelContent] = []
    
    // MARK: - Model Configuration
    
    /// Current model ID - change to "gemini-3-flash" for newer model when available
    private static let modelName = "gemini-2.5-flash"
    
    // MARK: - Initialization
    
    init(workoutService: WorkoutService) throws {
        self.workoutService = workoutService
        
        // Validate API key
        let apiKey = Secrets.geminiAPIKey
        guard !apiKey.isEmpty && apiKey != "YOUR_GEMINI_API_KEY_HERE" else {
            throw GeminiError.invalidAPIKey
        }
        
        // Create the model with tools and system instruction
        self.model = GenerativeModel(
            name: Self.modelName,
            apiKey: apiKey,
            generationConfig: GenerationConfig(
                temperature: 0.7,
                maxOutputTokens: 1024
            ),
            tools: [Tool(functionDeclarations: Self.functionDeclarations)],
            systemInstruction: ModelContent(role: "system", parts: [.text(SystemPrompt.persona)])
        )
    }
    
    // MARK: - Retry Configuration
    
    private static let maxRetries = 3
    private static let baseRetryDelay: TimeInterval = 1.0
    
    // MARK: - AIService Protocol
    
    func sendMessage(_ text: String, history: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.sendMessageWithRetry(text: text, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Send message with automatic retry on rate limit errors
    private func sendMessageWithRetry(
        text: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        attempt: Int = 0
    ) async throws {
        do {
            try await performSendMessage(text: text, continuation: continuation)
        } catch {
            // Check if this is a rate limit error that we should retry
            if isRateLimitError(error) && attempt < Self.maxRetries {
                let delay = Self.baseRetryDelay * pow(2.0, Double(attempt))
                print("Rate limited, retrying in \(delay)s (attempt \(attempt + 1)/\(Self.maxRetries))")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try await sendMessageWithRetry(text: text, continuation: continuation, attempt: attempt + 1)
            } else if attempt >= Self.maxRetries {
                throw GeminiError.maxRetriesExceeded
            } else {
                throw error
            }
        }
    }
    
    /// Perform the actual message send with error handling
    /// Uses generateContent directly to avoid SDK parsing bugs with Chat object
    private func performSendMessage(
        text: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        // Add user message to history
        let userContent = ModelContent(role: "user", parts: [.text(text)])
        conversationHistory.append(userContent)
        
        // Use generateContent instead of Chat to avoid SDK parsing bugs
        // The Chat object has issues when text history is followed by function call responses
        do {
            // WORKAROUND: Flatten text-only history to avoid SDK serialization bugs
            // The SDK often fails to decode responses when sending structured [ModelContent] history
            // if it only contains text. We flatten it to a single prompt string.
            var isTextOnly = true
            var flattenedPrompt = ""
            
            for content in conversationHistory {
                // Check if this content has any non-text parts
                let hasNonText = content.parts.contains { part in
                    if case .text = part { return false }
                    return true
                }
                
                if hasNonText {
                    isTextOnly = false
                    break
                }
                
                // Append text to flattened prompt with role labels
                if let text = content.parts.first?.text {
                    let label = (content.role == "user") ? "User" : "Spot"
                    flattenedPrompt += "\(label): \(text)\n"
                }
            }
            
            var response: GenerateContentResponse
            if isTextOnly && !flattenedPrompt.isEmpty {
                // Remove trailing newline
                if flattenedPrompt.hasSuffix("\n") {
                    flattenedPrompt.removeLast()
                }
                response = try await model.generateContent(flattenedPrompt)
            } else {
                response = try await model.generateContent(conversationHistory)
            }
            
            var fullResponse = ""
            
            // Process response - may need multiple rounds for function calls
            var maxRounds = 5 // Prevent infinite loops
            var currentRound = 0
            
            while currentRound < maxRounds {
                currentRound += 1
                
                // Check for safety block
                if let candidate = response.candidates.first,
                   candidate.finishReason == .safety {
                    continuation.yield("I can't respond to that. Could you try rephrasing?")
                    continuation.finish()
                    return
                }
                
                // Check for function calls first - this is the KEY fix
                let functionCalls = response.functionCalls
                if !functionCalls.isEmpty {
                    print("[GeminiService] Processing \(functionCalls.count) function calls")
                    
                    // Execute function calls
                    let functionResponses = await handleFunctionCalls(functionCalls)
                    
                    // Build fallback message based on function type
                    let fallbackMessage = buildFallbackMessage(for: functionCalls)
                    
                    // Add model's function call to history with EXPLICIT role
                    // The SDK might return nil role, so we enforce "model"
                    if let part = response.candidates.first?.content.parts.first {
                        let modelContent = ModelContent(role: "model", parts: [part])
                        conversationHistory.append(modelContent)
                    }
                    
                    // Add function response to history
                    let functionContent = ModelContent(role: "function", parts: functionResponses.map { .functionResponse($0) })
                    conversationHistory.append(functionContent)
                    
                    // Send function results back to Gemini for a natural response
                    do {
                        response = try await model.generateContent(conversationHistory)
                        
                        // Check if we got text back
                        if let responseText = response.text, !responseText.isEmpty {
                            // Filter out any JSON-like responses
                            let cleaned = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !cleaned.hasPrefix("{") || !cleaned.contains("\"name\"") {
                                fullResponse = cleaned
                                saveToHistory(fullResponse)
                                continuation.yield(fullResponse)
                            } else {
                                // Response is JSON, use fallback
                                saveToHistory(fallbackMessage)
                                continuation.yield(fallbackMessage)
                            }
                            continuation.finish()
                            return
                        } else {
                            // No text response, check for more function calls or use fallback
                            if response.functionCalls.isEmpty {
                                saveToHistory(fallbackMessage)
                                continuation.yield(fallbackMessage)
                                continuation.finish()
                                return
                            }
                            // More function calls - continue loop
                        }
                    } catch {
                        // Function follow-up failed, but function was executed - use fallback
                        print("[GeminiService] Function follow-up failed: \(error)")
                        saveToHistory(fallbackMessage)
                        continuation.yield(fallbackMessage)
                        continuation.finish()
                        return
                    }
                } else if let responseText = response.text, !responseText.isEmpty {
                    // Got text response
                    let cleaned = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned != "null" && !cleaned.hasPrefix("{") {
                        fullResponse = cleaned
                    } else if cleaned.hasPrefix("{") && cleaned.contains("log_workout_session") {
                        // Raw JSON leaked through - provide friendly message
                        fullResponse = "Got it! What are we hitting today?"
                    } else if fullResponse.isEmpty {
                        fullResponse = "I'm ready to help! What would you like to do?"
                    }
                    saveToHistory(fullResponse)
                    continuation.yield(fullResponse)
                    continuation.finish()
                    return
                } else {
                    // No function calls and no text - provide default response
                    let defaultResponse = "I'm ready to help! What would you like to do?"
                    saveToHistory(defaultResponse)
                    continuation.yield(defaultResponse)
                    continuation.finish()
                    return
                }
            }
            
            // Exceeded max rounds
            continuation.yield("I'm having trouble processing that. Could you try again?")
            continuation.finish()
            
        } catch {
            print("[GeminiService] Send error: \(error)")
            
            // Remove the user message we added since the request failed
            if !conversationHistory.isEmpty {
                conversationHistory.removeLast()
            }
            
            // Handle specific error types
            let errorMessage = String(describing: error)
            
            if errorMessage.contains("InvalidCandidateError") || 
               errorMessage.contains("malformedContent") ||
               errorMessage.contains("keyNotFound") {
                // SDK parsing error - often happens with edge cases
                continuation.yield("I couldn't process that request. Could you try rephrasing?")
                continuation.finish()
                return
            }
            
            if isRateLimitError(error) {
                throw error // Let retry logic handle it
            }
            
            // Generic error fallback
            continuation.yield("Something went wrong. Could you try again?")
            continuation.finish()
        }
    }
    
    /// Save assistant response to conversation history
    private func saveToHistory(_ text: String) {
        let modelContent = ModelContent(role: "model", parts: [.text(text)])
        conversationHistory.append(modelContent)
        
        // Keep history manageable - trim old messages if too long
        // Keep last 40 turns (80 messages) to avoid context overflow
        if conversationHistory.count > 80 {
            conversationHistory = Array(conversationHistory.suffix(80))
        }
    }
    
    /// Build a user-friendly fallback message based on the function that was called
    private func buildFallbackMessage(for functionCalls: [FunctionCall]) -> String {
        guard let firstCall = functionCalls.first else { return "Done!" }
        
        switch firstCall.name {
        case "log_workout_session":
            // Extract focus area if available
            if let focusArea = firstCall.args["focusArea"]?.stringValue {
                return "Starting \(focusArea)! What's your first exercise?"
            }
            return "Got it! What exercises are we doing?"
        case "log_sets":
            return "Logged! ✓"
        case "edit_set":
            return "Updated! ✓"
        case "delete_set":
            return "Deleted! ✓"
        case "get_recent_history":
            return "Here's your recent workout history."
        case "get_personal_record", "get_all_personal_records":
            return "Here are your PRs."
        case "get_last_exercise_stats":
            return "Here are your stats for that exercise."
        case "calculate_plate_math":
            return "Here's the plate breakdown."
        default:
            return "Done!"
        }
    }

    
    /// Check if an error is a rate limit error
    private func isRateLimitError(_ error: Error) -> Bool {
        let errorMessage = String(describing: error).lowercased()
        return errorMessage.contains("429") ||
               errorMessage.contains("rate") ||
               errorMessage.contains("quota") ||
               errorMessage.contains("resource exhausted")
    }
    
    func resetSession() {
        conversationHistory = []
    }
    
    func prewarm() {
        // No prewarm needed for Gemini
    }
    
    // MARK: - Function Declarations
    
    /// All function declarations matching our local tools
    private static var functionDeclarations: [FunctionDeclaration] {
        [
            // Log Workout Session
            FunctionDeclaration(
                name: "log_workout_session",
                description: "Starts a new workout session. Call IMMEDIATELY when user specifies a workout type: push day, pull day, leg day, chest, back, arms, shoulders, upper body, lower body, full body, etc.",
                parameters: [
                    "focusArea": Schema(
                        type: .string,
                        description: "The focus of the workout session (e.g., 'Push Day', 'Pull Day', 'Leg Day')",
                        nullable: false
                    )
                ],
                requiredParameters: ["focusArea"]
            ),
            
            // Log Sets
            FunctionDeclaration(
                name: "log_sets",
                description: "Records sets for an exercise. Call IMMEDIATELY when user reports sets.",
                parameters: [
                    "exerciseName": Schema(
                        type: .string,
                        description: "The exercise name (e.g., 'Bench Press', 'Squat')",
                        nullable: false
                    ),
                    "muscleGroup": Schema(
                        type: .string,
                        description: "Primary muscle group for this exercise. Must be one of: Chest, Back, Shoulders, Arms, Legs, Core, or Other",
                        nullable: true
                    ),
                    "weightLbs": Schema(
                        type: .number,
                        description: "Weight in pounds. Use the number from user input.",
                        nullable: true
                    ),
                    "reps": Schema(
                        type: .integer,
                        description: "Number of repetitions completed",
                        nullable: false
                    ),
                    "numberOfSets": Schema(
                        type: .integer,
                        description: "Number of sets to log (default 1)",
                        nullable: true
                    ),
                    "rpe": Schema(
                        type: .integer,
                        description: "Rate of Perceived Exertion from 1-10",
                        nullable: true
                    ),
                    "isBodyweight": Schema(
                        type: .boolean,
                        description: "True if bodyweight exercise with no added weight",
                        nullable: true
                    )
                ],
                requiredParameters: ["exerciseName", "reps"]
            ),
            
            // Edit Set
            FunctionDeclaration(
                name: "edit_set",
                description: "Updates an existing set with new weight or reps.",
                parameters: [
                    "exerciseName": Schema(
                        type: .string,
                        description: "The exercise to edit",
                        nullable: false
                    ),
                    "setIdentifier": Schema(
                        type: .string,
                        description: "Which set to edit: 'last', 'first', or set number",
                        nullable: false
                    ),
                    "newWeight": Schema(
                        type: .number,
                        description: "New weight in pounds",
                        nullable: true
                    ),
                    "newReps": Schema(
                        type: .integer,
                        description: "New rep count",
                        nullable: true
                    )
                ],
                requiredParameters: ["exerciseName", "setIdentifier"]
            ),
            
            // Delete Set
            FunctionDeclaration(
                name: "delete_set",
                description: "Deletes a logged set from the current workout.",
                parameters: [
                    "exerciseName": Schema(
                        type: .string,
                        description: "The exercise to delete from",
                        nullable: false
                    ),
                    "setIdentifier": Schema(
                        type: .string,
                        description: "Which set to delete: 'last', 'first', 'all', or set number",
                        nullable: false
                    )
                ],
                requiredParameters: ["exerciseName", "setIdentifier"]
            ),
            
            // Get Recent History
            FunctionDeclaration(
                name: "get_recent_history",
                description: "Fetches the user's recent workout sessions.",
                parameters: [
                    "limit": Schema(
                        type: .integer,
                        description: "Number of sessions to retrieve (default 3, max 10)",
                        nullable: true
                    )
                ],
                requiredParameters: []
            ),
            
            // Get Last Exercise Stats
            FunctionDeclaration(
                name: "get_last_exercise_stats",
                description: "Gets stats from the last time user performed an exercise.",
                parameters: [
                    "exerciseName": Schema(
                        type: .string,
                        description: "The exercise to look up",
                        nullable: false
                    )
                ],
                requiredParameters: ["exerciseName"]
            ),
            
            // Get Personal Record
            FunctionDeclaration(
                name: "get_personal_record",
                description: "Gets the user's all-time personal record for a specific exercise.",
                parameters: [
                    "exerciseName": Schema(
                        type: .string,
                        description: "The exercise to get the PR for",
                        nullable: false
                    )
                ],
                requiredParameters: ["exerciseName"]
            ),
            
            // Get All Personal Records
            FunctionDeclaration(
                name: "get_all_personal_records",
                description: "Gets all personal records across exercises.",
                parameters: [
                    "limit": Schema(
                        type: .integer,
                        description: "Maximum number of PRs to return (default 5)",
                        nullable: true
                    ),
                    "muscleGroup": Schema(
                        type: .string,
                        description: "Optional filter by muscle group",
                        nullable: true
                    )
                ],
                requiredParameters: []
            ),
            
            // Calculate Plate Math
            FunctionDeclaration(
                name: "calculate_plate_math",
                description: "Converts gym plate slang into total weight. '1 plate' = 135 lbs, '2 plates' = 225 lbs. ALWAYS call this FIRST before log_sets when you see plate slang.",
                parameters: [
                    "inputString": Schema(
                        type: .string,
                        description: "The gym slang to convert (e.g., '2 plates', '1 plate and a 25')",
                        nullable: false
                    )
                ],
                requiredParameters: ["inputString"]
            )
        ]
    }
    
    // MARK: - Function Call Handling
    
    /// Execute function calls and return responses
    private func handleFunctionCalls(_ calls: [FunctionCall]) async -> [FunctionResponse] {
        var responses: [FunctionResponse] = []
        
        for call in calls {
            let result = await executeFunctionCall(call)
            responses.append(FunctionResponse(name: call.name, response: ["result": .string(result)]))
        }
        
        return responses
    }
    
    /// Execute a single function call using existing WorkoutService methods
    private func executeFunctionCall(_ call: FunctionCall) async -> String {
        let args = call.args
        
        switch call.name {
        case "log_workout_session":
            guard let focusArea = args["focusArea"]?.stringValue else {
                return "Error: focusArea is required"
            }
            _ = workoutService.startSession(label: focusArea)
            return "Started \(focusArea) session. Ready to log exercises!"
            
        case "log_sets":
            guard let exerciseName = args["exerciseName"]?.stringValue,
                  let reps = args["reps"]?.intValue else {
                return "Error: exerciseName and reps are required"
            }
            let weight = args["weightLbs"]?.doubleValue ?? 0
            let numberOfSets = args["numberOfSets"]?.intValue ?? 1
            let rpe = args["rpe"]?.intValue
            let isBodyweight = args["isBodyweight"]?.boolValue ?? false
            
            // Use LLM-provided muscle group, fall back to keyword matching if not provided
            let muscleGroup = Self.normalizedMuscleGroup(args["muscleGroup"]?.stringValue) 
                ?? Self.guessMuscleGroup(for: exerciseName)
            
            var results: [String] = []
            for _ in 0..<numberOfSets {
                if let result = workoutService.logSet(
                    exerciseName: exerciseName,
                    weight: weight,
                    reps: reps,
                    rpe: rpe,
                    muscleGroup: muscleGroup,
                    isBodyweight: isBodyweight
                ) {
                    // Use actual weight from the logged set
                    let actualWeight = result.set.weight
                    let weightDisplay: String
                    if isBodyweight {
                        weightDisplay = actualWeight > 0 ? "BW (\(Int(actualWeight)))" : "BW"
                    } else {
                        weightDisplay = "\(Int(actualWeight)) lbs"
                    }
                    
                    var response = "Logged: \(result.exercise.name) - \(weightDisplay) x \(reps)"
                    if result.isPR {
                        response += " - NEW PR!"
                    }
                    results.append(response)
                } else {
                    return "No active workout session. Start one first!"
                }
            }
            return results.joined(separator: "\n")
            
        case "edit_set":
            guard let exerciseName = args["exerciseName"]?.stringValue,
                  let setIdentifier = args["setIdentifier"]?.stringValue else {
                return "Error: exerciseName and setIdentifier are required"
            }
            let newWeight = args["newWeight"]?.doubleValue
            let newReps = args["newReps"]?.intValue
            
            if let result = workoutService.editSet(
                exerciseName: exerciseName,
                setIdentifier: setIdentifier,
                newWeight: newWeight,
                newReps: newReps
            ) {
                return "Updated: \(result.exerciseName) set \(result.setNumber) → \(Int(result.weight)) lbs x \(result.reps)"
            }
            return "Couldn't find that set to edit."
            
        case "delete_set":
            guard let exerciseName = args["exerciseName"]?.stringValue,
                  let setIdentifier = args["setIdentifier"]?.stringValue else {
                return "Error: exerciseName and setIdentifier are required"
            }
            if let result = workoutService.deleteSet(exerciseName: exerciseName, setIdentifier: setIdentifier) {
                return "Deleted set \(result.setNumber) from \(result.exerciseName)."
            }
            return "Couldn't find sets to delete."
            
        case "get_recent_history":
            let limit = args["limit"]?.intValue ?? 3
            let sessions = workoutService.getRecentSessions(limit: min(limit, 10))
            if sessions.isEmpty {
                return "No workout history found."
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let summaries = sessions.map { session in
                "\(formatter.string(from: session.startTime)): \(session.label) (\(session.exercises.count) exercises)"
            }
            return "Recent workouts: " + summaries.joined(separator: "; ")
            
        case "get_last_exercise_stats":
            guard let exerciseName = args["exerciseName"]?.stringValue else {
                return "Error: exerciseName is required"
            }
            if let stats = workoutService.getLastExerciseStats(exerciseName: exerciseName) {
                let topSet = stats.orderedSets.max(by: { $0.weight < $1.weight })
                if let top = topSet {
                    return "Last \(exerciseName): \(Int(top.weight)) lbs x \(top.reps)"
                }
            }
            return "No previous data for \(exerciseName)."
            
        case "get_personal_record":
            guard let exerciseName = args["exerciseName"]?.stringValue else {
                return "Error: exerciseName is required"
            }
            if let pr = workoutService.getPR(exerciseName: exerciseName) {
                return "PR for \(exerciseName): \(Int(pr.weight)) lbs"
            }
            return "No PR recorded for \(exerciseName) yet."
            
        case "get_all_personal_records":
            let limit = args["limit"]?.intValue ?? 5
            let muscleGroup = args["muscleGroup"]?.stringValue
            let result = workoutService.getAllPRs(limit: limit, muscleGroup: muscleGroup)
            if result.prs.isEmpty {
                return "No PRs recorded yet."
            }
            let prStrings = result.prs.map { "\($0.exerciseName): \(Int($0.weight)) lbs" }
            return "Your PRs: " + prStrings.joined(separator: ", ")
            
        case "calculate_plate_math":
            guard let inputString = args["inputString"]?.stringValue else {
                return "Error: inputString is required"
            }
            let result = PlateMathCalculator.calculate(from: inputString)
            return "Total weight: \(result.totalWeight) lbs. Breakdown: \(result.breakdown)"
            
        default:
            return "Unknown function: \(call.name)"
        }
    }
    
    // MARK: - Muscle Group Helper
    
    /// Valid muscle group categories
    private static let validMuscleGroups = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Other"]
    
    /// Normalize and validate a muscle group string from the LLM
    /// Returns nil if the input is invalid, allowing fallback to keyword matching
    private static func normalizedMuscleGroup(_ input: String?) -> String? {
        guard let input = input, !input.isEmpty else { return nil }
        
        let lowercased = input.lowercased()
        
        // Map common variations to standard categories
        if lowercased.contains("chest") || lowercased.contains("pec") {
            return "Chest"
        }
        if lowercased.contains("back") || lowercased.contains("lat") {
            return "Back"
        }
        if lowercased.contains("shoulder") || lowercased.contains("delt") {
            return "Shoulders"
        }
        if lowercased.contains("arm") || lowercased.contains("bicep") || lowercased.contains("tricep") {
            return "Arms"
        }
        if lowercased.contains("leg") || lowercased.contains("quad") || lowercased.contains("ham") || lowercased.contains("glute") || lowercased.contains("calf") {
            return "Legs"
        }
        if lowercased.contains("core") || lowercased.contains("ab") {
            return "Core"
        }
        if lowercased.contains("other") {
            return "Other"
        }
        
        // If it's already a valid category, use it
        if let match = validMuscleGroups.first(where: { $0.lowercased() == lowercased }) {
            return match
        }
        
        return nil  // Fall back to keyword matching
    }
    
    /// Guess the muscle group for an exercise based on its name (fallback)
    private static func guessMuscleGroup(for exercise: String) -> String {
        let lowercased = exercise.lowercased()
        
        // Chest exercises
        if lowercased.contains("bench") || lowercased.contains("chest") || 
           lowercased.contains("fly") || lowercased.contains("flye") ||
           lowercased.contains("pec") || lowercased.contains("dip") ||
           lowercased.contains("push-up") || lowercased.contains("pushup") ||
           lowercased.contains("cable cross") || lowercased.contains("incline press") ||
           lowercased.contains("decline press") {
            return "Chest"
        }
        
        // Back exercises
        if lowercased.contains("deadlift") || lowercased.contains("row") || 
           lowercased.contains("pull up") || lowercased.contains("pull-up") || lowercased.contains("pullup") ||
           lowercased.contains("chin up") || lowercased.contains("chin-up") || lowercased.contains("chinup") ||
           lowercased.contains("lat") || lowercased.contains("back") ||
           lowercased.contains("pulldown") || lowercased.contains("pull down") ||
           lowercased.contains("shrug") || lowercased.contains("hyperextension") ||
           lowercased.contains("face pull") || lowercased.contains("reverse fly") {
            return "Back"
        }
        
        // Shoulders exercises
        if lowercased.contains("shoulder") || lowercased.contains("delt") || 
           lowercased.contains("ohp") || lowercased.contains("military") ||
           lowercased.contains("overhead press") || lowercased.contains("lateral raise") ||
           lowercased.contains("front raise") || lowercased.contains("rear delt") ||
           lowercased.contains("arnold") || lowercased.contains("upright row") {
            return "Shoulders"
        }
        
        // Arms exercises
        if lowercased.contains("curl") || lowercased.contains("bicep") || 
           lowercased.contains("tricep") || lowercased.contains("extension") ||
           lowercased.contains("pushdown") || lowercased.contains("push down") ||
           lowercased.contains("hammer") || lowercased.contains("preacher") ||
           lowercased.contains("skullcrusher") || lowercased.contains("skull crusher") ||
           lowercased.contains("kickback") || lowercased.contains("forearm") ||
           lowercased.contains("wrist") {
            return "Arms"
        }
        
        // Legs exercises
        if lowercased.contains("squat") || lowercased.contains("leg") || 
           lowercased.contains("lunge") || lowercased.contains("calf") || 
           lowercased.contains("glute") || lowercased.contains("ham") ||
           lowercased.contains("quad") || lowercased.contains("hip") ||
           lowercased.contains("rdl") || lowercased.contains("romanian") ||
           lowercased.contains("step up") || lowercased.contains("split squat") ||
           lowercased.contains("thrust") || lowercased.contains("bridge") {
            return "Legs"
        }
        
        // Core exercises
        if lowercased.contains("crunch") || lowercased.contains("sit-up") ||
           lowercased.contains("situp") || lowercased.contains("plank") ||
           lowercased.contains("ab ") || lowercased.contains("abs") ||
           lowercased.contains("core") || lowercased.contains("oblique") ||
           lowercased.contains("russian twist") || lowercased.contains("leg raise") ||
           lowercased.contains("hanging") || lowercased.contains("wood chop") {
            return "Core"
        }
        
        // Press without leg context defaults to Chest
        if lowercased.contains("press") && !lowercased.contains("leg") {
            return "Chest"
        }
        
        return "Other"
    }
}

// MARK: - JSON Value Extensions

extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }
    
    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }
}
