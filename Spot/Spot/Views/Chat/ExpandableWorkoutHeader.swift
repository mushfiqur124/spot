//
//  ExpandableWorkoutHeader.swift
//  Spot
//
//  Expandable header showing current workout details.
//  Can be tapped or dragged to expand/collapse.
//

import SwiftUI

struct ExpandableWorkoutHeader: View {
    let session: WorkoutSession?
    let conversation: Conversation?
    let userProfile: UserProfile?
    let onMenuTap: () -> Void
    let onNewChat: () -> Void
    var onOpenDashboard: (() -> Void)? = nil
    
    @Binding var isExpanded: Bool
    
    // Drag state
    @GestureState private var dragOffset: CGFloat = 0
    
    // Animation
    @State private var showExercises: Bool = false
    
    private let expandedHeight: CGFloat = 300
    private let collapsedHeight: CGFloat = 70
    
    var body: some View {
        VStack(spacing: 0) {
            // Main header content
            mainHeader
            
            // Expandable exercise list
            if isExpanded {
                exerciseList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .background(SpotTheme.canvas)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.height > threshold && !isExpanded {
                        withAnimation { isExpanded = true }
                    } else if value.translation.height < -threshold && isExpanded {
                        withAnimation { isExpanded = false }
                    }
                }
        )
    }
    
    // MARK: - Main Header
    
    private var mainHeader: some View {
        HStack(alignment: .center, spacing: SpotTheme.Spacing.sm) {
            // Menu button
            Button(action: onMenuTap) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SpotTheme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            
            // Title section
            VStack(alignment: .leading, spacing: 2) {
                if let session = session {
                    // Active workout - show workout name prominently
                    Text(session.label)
                        .font(SpotTheme.Typography.title2)
                        .foregroundStyle(SpotTheme.textPrimary)
                    
                    Text(formattedDate(session.startTime))
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                } else if let conversation = conversation, !conversation.messages.isEmpty {
                    // Active general conversation
                    Text(conversation.title)
                        .font(SpotTheme.Typography.title2)
                        .foregroundStyle(SpotTheme.textPrimary)
                    
                    Text(formattedDate(conversation.createdAt))
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                } else {
                    // No active session or conversation - show Spot branding
                    Text("Spot")
                        .font(SpotTheme.Typography.title)
                        .foregroundStyle(SpotTheme.textPrimary)
                    
                    if let profile = userProfile {
                        Text("Ready to train, \(profile.firstName)?")
                            .font(SpotTheme.Typography.caption)
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Right side buttons
            if hasActiveConversation {
                // Show new chat and expand buttons when there's an active conversation
                HStack(spacing: SpotTheme.Spacing.sm) {
                    // New chat button
                    Button {
                        onNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                    
                    // Expand/collapse indicator (only for workouts with exercises)
                    if let session = session, session.exercises.count > 0 {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(SpotTheme.textSecondary)
                        }
                    }
                }
            } else if let onOpenDashboard = onOpenDashboard {
                // Show dashboard button when chat is empty
                Button {
                    onOpenDashboard()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(SpotTheme.sage)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.sm)
        .padding(.vertical, SpotTheme.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            if session?.exercises.count ?? 0 > 0 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Whether there's an active conversation with content
    private var hasActiveConversation: Bool {
        // Has an active workout session
        if session != nil {
            return true
        }
        // Has a general conversation with messages
        if let conversation = conversation, !conversation.messages.isEmpty {
            return true
        }
        return false
    }
    
    // MARK: - Exercise List
    
    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(SpotTheme.textSecondary.opacity(0.1))
            
            if let session = session {
                let exercises = session.orderedExercises
                
                if exercises.isEmpty {
                    emptyExerciseState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
                            ForEach(exercises) { workoutExercise in
                                ExerciseRow(workoutExercise: workoutExercise)
                            }
                        }
                        .padding(.horizontal, SpotTheme.Spacing.md)
                        .padding(.vertical, SpotTheme.Spacing.sm)
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyExerciseState: some View {
        VStack(spacing: SpotTheme.Spacing.xs) {
            Text("No exercises logged yet")
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textSecondary)
            
            Text("Tell me what you're doing!")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpotTheme.Spacing.lg)
    }
    
    // MARK: - Helpers
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Exercise Row

private struct ExerciseRow: View {
    let workoutExercise: WorkoutExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.xxs) {
            HStack {
                Text(workoutExercise.exercise?.name ?? "Unknown")
                    .font(SpotTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Spacer()
                
                Text("\(workoutExercise.sets.count) sets")
                    .font(SpotTheme.Typography.caption)
                    .foregroundStyle(SpotTheme.textSecondary)
                
                if workoutExercise.hasPR {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(SpotTheme.sage)
                }
            }
            
            // Show sets summary
            HStack(spacing: SpotTheme.Spacing.xs) {
                ForEach(workoutExercise.orderedSets.prefix(5)) { set in
                    Text(set.quickSummary)
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                        .padding(.horizontal, SpotTheme.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(SpotTheme.textPrimary.opacity(0.05))
                        )
                }
                
                if workoutExercise.sets.count > 5 {
                    Text("+\(workoutExercise.sets.count - 5)")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, SpotTheme.Spacing.xs)
    }
}

// MARK: - Preview

#Preview("Header - No Session") {
    VStack {
        ExpandableWorkoutHeader(
            session: nil,
            conversation: nil,
            userProfile: nil,
            onMenuTap: { },
            onNewChat: { },
            isExpanded: .constant(false)
        )
        Spacer()
    }
    .background(SpotTheme.canvas)
}

#Preview("Header - Active Session") {
    VStack {
        ExpandableWorkoutHeader(
            session: nil,
            conversation: nil,
            userProfile: nil,
            onMenuTap: { },
            onNewChat: { },
            isExpanded: .constant(true)
        )
        Spacer()
    }
    .background(SpotTheme.canvas)
}

