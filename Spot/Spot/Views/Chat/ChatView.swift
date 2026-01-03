//
//  ChatView.swift
//  Spot
//
//  Main chat interface - the home screen of the app.
//  Clean, editorial design with solid canvas background.
//

import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ChatViewModel
    
    // User profile for personalization
    let userProfile: UserProfile?
    
    // Callback to open dashboard
    var onOpenDashboard: (() -> Void)?
    
    // For scroll-to-bottom behavior
    @Namespace private var bottomAnchor
    
    // UI State
    @State private var showHistoryPanel: Bool = false
    @State private var headerExpanded: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var exerciseSuggestions: [Exercise] = []
    
    // Swipe gesture threshold
    private let swipeThreshold: CGFloat = 100
    private let panelWidth: CGFloat = 280
    
    init(modelContext: ModelContext, userProfile: UserProfile? = nil, onOpenDashboard: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(modelContext: modelContext))
        self.userProfile = userProfile
        self.onOpenDashboard = onOpenDashboard
    }
    
    var body: some View {
        ZStack {
            // Solid canvas background
            SpotTheme.canvas
                .ignoresSafeArea()
            
            // Main content
            mainContent
                .offset(x: showHistoryPanel ? panelWidth : max(0, dragOffset))
            
            // Dimming overlay when panel is open
            if showHistoryPanel || dragOffset > 0 {
                Color.black
                    .opacity(overlayOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showHistoryPanel = false
                        }
                    }
                    .offset(x: showHistoryPanel ? panelWidth : dragOffset)
            }
            
            // Side panel
            HStack(spacing: 0) {
                WorkoutHistoryPanel(
                    userProfile: userProfile,
                    currentConversation: viewModel.currentConversation,
                    onSelectConversation: { conversation in
                        viewModel.switchToConversation(conversation)
                    },
                    onNewChat: {
                        viewModel.startNewConversation()
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showHistoryPanel = false
                        }
                    },
                    onOpenDashboard: {
                        onOpenDashboard?()
                    }
                )
                .offset(x: showHistoryPanel ? 0 : -panelWidth + max(0, dragOffset))
                
                Spacer()
            }
        }
        .gesture(edgeSwipeGesture)
        .animation(.easeOut(duration: 0.25), value: showHistoryPanel)
        .animation(.easeInOut(duration: 0.25), value: shouldShowQuickActions)
    }
    
    // MARK: - Overlay Opacity
    
    private var overlayOpacity: Double {
        if showHistoryPanel {
            return 0.3
        } else {
            return Double(dragOffset / panelWidth) * 0.3
        }
    }
    
    // MARK: - Edge Swipe Gesture
    
    private var edgeSwipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow swipe from left edge when panel is closed
                if !showHistoryPanel && value.startLocation.x < 30 {
                    dragOffset = max(0, value.translation.width)
                }
                // Allow swipe to close
                else if showHistoryPanel && value.translation.width < 0 {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                if !showHistoryPanel {
                    if value.translation.width > swipeThreshold {
                        showHistoryPanel = true
                    }
                } else {
                    if value.translation.width < -swipeThreshold {
                        showHistoryPanel = false
                    }
                }
                dragOffset = 0
            }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Main VStack content
            VStack(spacing: 0) {
                // Expandable Header
                ExpandableWorkoutHeader(
                    session: viewModel.activeSession,
                    conversation: viewModel.currentConversation,
                    userProfile: userProfile,
                    onMenuTap: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showHistoryPanel = true
                        }
                    },
                    onNewChat: {
                        viewModel.startNewConversation()
                    },
                    onOpenDashboard: onOpenDashboard,
                    isExpanded: $headerExpanded
                )
                
                // Messages
                messagesScrollView
                
                // Quick actions (only show when appropriate)
                if shouldShowQuickActions {
                    quickActionsView
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // Input
                InputCapsule(
                    text: $viewModel.inputText,
                    placeholder: "Message Spot...",
                    onSend: {
                        Task {
                            await viewModel.sendMessageStreaming()
                        }
                    }
                )
            }
            
            // Floating exercise suggestion pills (above input, transparent background)
            if !exerciseSuggestions.isEmpty && viewModel.activeSession != nil {
                VStack(spacing: 0) {
                    Spacer()
                    
                    ExerciseSuggestionPills(exercises: exerciseSuggestions) { exercise in
                        // Auto-send the exercise name
                        viewModel.inputText = exercise.name
                        Task {
                            await viewModel.sendMessageStreaming()
                        }
                    }
                    .padding(.bottom, shouldShowQuickActions ? 100 : 70) // Space for input + quick actions
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onChange(of: viewModel.activeSession?.label) { _, newLabel in
            updateExerciseSuggestions()
        }
        .onChange(of: viewModel.activeSession?.exercises.count) { _, _ in
            updateExerciseSuggestions()
        }
        .onAppear {
            updateExerciseSuggestions()
        }
    }
    
    /// Update exercise suggestions based on workout label, excluding exercises already done
    private func updateExerciseSuggestions() {
        guard let session = viewModel.activeSession,
              let label = session.label as String? else {
            exerciseSuggestions = []
            return
        }
        
        // Get names of exercises already performed in this session
        let alreadyDone = Set(session.exercises.compactMap { $0.exercise?.name })
        
        let service = ExerciseSuggestionService(modelContext: modelContext)
        exerciseSuggestions = service.getSuggestions(for: label, limit: 6, excluding: alreadyDone)
    }
    
    private var shouldShowQuickActions: Bool {
        viewModel.messages.isEmpty || (viewModel.showQuickActions && !viewModel.isLoading)
    }
    
    // MARK: - Messages
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: SpotTheme.Spacing.sm) {
                    // Welcome message if empty
                    if viewModel.messages.isEmpty {
                        welcomeMessage
                    }
                    
                    // Chat messages
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, onEditExercise: handleEditExercise)
                    }
                    
                    // Streaming response (shows while AI is responding)
                    // Only show streaming bubble when we have actual content that isn't a logging response
                    if viewModel.isLoading && viewModel.streamingResponse.count > 0 && 
                       viewModel.streamingResponse != "null" && 
                       !viewModel.isLoggingResponse {
                        MessageBubble(message: .assistant(viewModel.streamingResponse, isStreaming: true))
                    } else if viewModel.isLoading {
                        // Show typing indicator when waiting, or when logging (card will appear after)
                        TypingIndicator()
                    }
                    
                    // Invisible anchor for scrolling
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding(.vertical, SpotTheme.Spacing.sm)
                // Tap anywhere on empty space to dismiss keyboard (matches Claude/ChatGPT/Gemini iOS)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isLoading) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.streamingResponse) { _, _ in
                // Scroll as new streaming content arrives
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Welcome Message
    
    private var welcomeMessage: some View {
        VStack(spacing: SpotTheme.Spacing.md) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(SpotTheme.clay.opacity(0.6))
            
            VStack(spacing: SpotTheme.Spacing.xs) {
                Text(motivationalGreeting)
                    .font(SpotTheme.Typography.title2)
                    .foregroundStyle(SpotTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Tell me what you're hitting today.")
                    .font(SpotTheme.Typography.body)
                    .foregroundStyle(SpotTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, SpotTheme.Spacing.xl)
            
            Spacer()
        }
    }
    
    // MARK: - Motivational Greetings
    
    private var motivationalGreeting: String {
        let firstName = userProfile?.firstName ?? "champ"
        let greetings = [
            "Time to get after it, \(firstName).",
            "Let's build something today, \(firstName).",
            "Ready when you are, \(firstName).",
            "What are we hitting today, \(firstName)?",
            "Let's make it count, \(firstName).",
            "Another day, another gain, \(firstName)."
        ]
        
        // Use a seed based on the day so it changes daily but is consistent within a day
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let index = dayOfYear % greetings.count
        return greetings[index]
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsView: some View {
        QuickActionPills { action in
            viewModel.inputText = action.prompt
            Task {
                await viewModel.sendMessageStreaming()
            }
        }
        .padding(.vertical, SpotTheme.Spacing.sm)
    }
    
    // MARK: - Keyboard Dismiss Helper
    
    /// Dismisses the keyboard by resigning first responder (matches modern chat app behavior)
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Edit Exercise Handler
    
    private func handleEditExercise(
        exercise: LoggedExerciseInfo.ExerciseEntry,
        newName: String,
        updatedSets: [(weight: Double, reps: Int)]
    ) {
        // Call the workout service to update the exercise
        let success = viewModel.updateExercise(
            originalName: exercise.exerciseName,
            newName: newName,
            updatedSets: updatedSets
        )
        
        // Reload messages to reflect changes
        if success {
            viewModel.reloadCurrentMessages()
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Chat View") {
    let container = SampleData.previewContainer
    
    return ChatView(modelContext: container.mainContext, userProfile: nil)
        .modelContainer(container)
}

@available(iOS 26.0, *)
#Preview("Chat View - Dark") {
    let container = SampleData.previewContainer
    
    return ChatView(modelContext: container.mainContext, userProfile: nil)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
