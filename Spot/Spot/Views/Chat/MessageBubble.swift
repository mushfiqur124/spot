//
//  MessageBubble.swift
//  Spot
//
//  Chat bubble component with different styles for user/AI messages.
//  User: Solid clay background
//  AI: Subtle warm glass effect
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var onEditExercise: ((LoggedExerciseInfo.ExerciseEntry, String, [(weight: Double, reps: Int)]) -> Void)? = nil
    var onDeleteExercise: ((String) -> Void)? = nil
    
    // Animation states
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    
    // Check if message contains PR celebration (but not if showing logged exercise UI)
    private var containsPR: Bool {
        // Don't show PR badge if we're showing the logged exercise card (it has its own PR display)
        guard message.loggedExerciseInfo == nil else { return false }
        
        return message.content.lowercased().contains("new pr") || 
               message.content.contains("🎉")
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: SpotTheme.Spacing.xs) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: SpotTheme.Spacing.xs) {
                bubbleContent
                
                // Show PR badge if this is a PR message
                if containsPR && message.isAssistant {
                    PRBadge()
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.md)
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                opacity = 1
                offset = 0
            }
        }
    }
    
    @ViewBuilder
    private var bubbleContent: some View {
        if message.isUser {
            userBubble
        } else if let loggedInfo = message.loggedExerciseInfo {
            // Show logged exercise card instead of text bubble
            SetLoggedCard(info: loggedInfo, onEdit: onEditExercise, onDelete: onDeleteExercise)
        } else {
            aiBubble
        }
    }
    
    // MARK: - User Bubble (Solid Clay)
    
    private var userBubble: some View {
        Text(message.content)
            .font(SpotTheme.Typography.body)
            .foregroundStyle(SpotTheme.onClay)
            .padding(.horizontal, SpotTheme.Spacing.md)
            .padding(.vertical, SpotTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SpotTheme.Radius.bubble, style: .continuous)
                    .fill(SpotTheme.clay)
            )
            .clipShape(
                BubbleShape(isUser: true)
            )
    }
    
    // MARK: - AI Bubble (Warm Glass)
    
    private var aiBubble: some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.xxs) {
            // Render markdown content
            Text(markdownContent)
                .font(SpotTheme.Typography.body)
                .foregroundStyle(SpotTheme.textPrimary)
            
            // Show streaming indicator if message is being typed
            if message.isStreaming {
                streamingIndicator
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.md)
        .padding(.vertical, SpotTheme.Spacing.sm)
        .warmGlass(style: .subtle, cornerRadius: SpotTheme.Radius.bubble)
    }
    
    // MARK: - Markdown Rendering
    
    private var markdownContent: AttributedString {
        do {
            let attributed = try AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            return attributed
        } catch {
            // Fallback to plain text if markdown parsing fails
            return AttributedString(message.content)
        }
    }
    
    // MARK: - Streaming Indicator
    
    private var streamingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(SpotTheme.textSecondary)
                    .frame(width: 4, height: 4)
                    .opacity(0.6)
            }
        }
        .padding(.top, SpotTheme.Spacing.xxs)
    }
}

// MARK: - Custom Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius = SpotTheme.Radius.bubble
        
        var path = Path()
        
        if isUser {
            // User bubble - rounded on left, slightly pointed on bottom-right
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: radius, height: radius),
                style: .continuous
            )
        } else {
            // AI bubble - rounded on right, slightly pointed on bottom-left
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: radius, height: radius),
                style: .continuous
            )
        }
        
        return path
    }
}

// MARK: - Preview

#Preview("Message Bubbles") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack(spacing: SpotTheme.Spacing.md) {
            MessageBubble(message: .assistant("Hey! Ready to get after it today? What are we hitting?"))
            
            MessageBubble(message: .user("Push day"))
            
            MessageBubble(message: .assistant("Let's go! You haven't hit chest in 3 days. Last push session you benched 175 for 6. Feeling strong today?"))
            
            MessageBubble(message: .user("Yeah let's start with bench. 135 for 8"))
            
            MessageBubble(message: .assistant("Logged: Bench Press 135 x 8. Good warm-up set. What's next?", isStreaming: true))
        }
        .padding(.vertical)
    }
}

