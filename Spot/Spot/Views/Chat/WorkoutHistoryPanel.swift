//
//  WorkoutHistoryPanel.swift
//  Spot
//
//  Side panel showing conversation history.
//  Shows both workout sessions and general chats.
//

import SwiftUI
import SwiftData

struct WorkoutHistoryPanel: View {
    @Environment(\.modelContext) private var modelContext
    
    let userProfile: UserProfile?
    let currentConversation: Conversation?
    let onSelectConversation: (Conversation) -> Void
    let onNewChat: () -> Void
    let onDismiss: () -> Void
    let onOpenDashboard: () -> Void
    
    @State private var conversations: [Conversation] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            headerView
            
            Divider()
                .background(SpotTheme.textSecondary.opacity(0.2))
            
            // Dashboard button
            dashboardButton
                .padding(.vertical, SpotTheme.Spacing.sm)
            
            Divider()
                .background(SpotTheme.textSecondary.opacity(0.2))
            
            // Conversation history list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if conversations.isEmpty {
                        emptyState
                    } else {
                        ForEach(sortedGroupKeys, id: \.self) { key in
                            if let conversationsInGroup = groupedConversations[key] {
                                Section {
                                    ForEach(conversationsInGroup) { conversation in
                                        ConversationRow(
                                            conversation: conversation,
                                            isSelected: conversation.id == currentConversation?.id
                                        ) {
                                            onSelectConversation(conversation)
                                            onDismiss()
                                        }
                                    }
                                } header: {
                                    Text(key)
                                        .font(SpotTheme.Typography.caption)
                                        .foregroundStyle(SpotTheme.textSecondary)
                                        .padding(.horizontal, SpotTheme.Spacing.md)
                                        .padding(.top, SpotTheme.Spacing.md)
                                        .padding(.bottom, SpotTheme.Spacing.xs)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .frame(width: 280)
        .background(SpotTheme.canvas)
        .onAppear {
            loadConversations()
        }
        .onChange(of: currentConversation?.id) { _, _ in
            // Refresh when conversation changes
            loadConversations()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: SpotTheme.Spacing.sm) {
            // Profile avatar
            Circle()
                .fill(SpotTheme.clay.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(userProfile?.firstName.prefix(1).uppercased() ?? "?")
                        .font(SpotTheme.Typography.headline)
                        .foregroundStyle(SpotTheme.clay)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(userProfile?.firstName ?? "Athlete")
                    .font(SpotTheme.Typography.headline)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                let workoutCount = conversations.filter { $0.isWorkout }.count
                Text("\(workoutCount) workout\(workoutCount == 1 ? "" : "s")")
                    .font(SpotTheme.Typography.caption)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            Spacer()
            
            // New chat button in header
            Button {
                onNewChat()
                onDismiss()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SpotTheme.clay)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.md)
        .padding(.vertical, SpotTheme.Spacing.md)
    }
    
    // MARK: - Dashboard Button
    
    private var dashboardButton: some View {
        Button {
            onOpenDashboard()
            onDismiss()
        } label: {
            HStack(spacing: SpotTheme.Spacing.sm) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(SpotTheme.sage)
                
                Text("Dashboard")
                    .font(SpotTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, SpotTheme.Spacing.md)
            .padding(.vertical, SpotTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: SpotTheme.Spacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.5))
            
            Text("No conversations yet")
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textSecondary)
            
            Text("Start chatting with Spot!")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpotTheme.Spacing.xxl)
    }
    
    // MARK: - Data Loading
    
    private func loadConversations() {
        var descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        
        let allConversations = (try? modelContext.fetch(descriptor)) ?? []
        
        // Only show conversations that have messages
        conversations = allConversations.filter { !$0.messages.isEmpty }
    }
    
    // MARK: - Grouping
    
    /// Order for date groups (newest first)
    private static let groupOrder = ["Today", "Yesterday", "This Week", "Last Week", "This Month", "Earlier"]
    
    /// Sorted group keys in chronological order (newest first)
    private var sortedGroupKeys: [String] {
        let keys = Array(groupedConversations.keys)
        return keys.sorted { key1, key2 in
            let index1 = Self.groupOrder.firstIndex(of: key1) ?? Self.groupOrder.count
            let index2 = Self.groupOrder.firstIndex(of: key2) ?? Self.groupOrder.count
            return index1 < index2
        }
    }
    
    private var groupedConversations: [String: [Conversation]] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [String: [Conversation]] = [:]
        
        for conversation in conversations {
            let key = groupKey(for: conversation.lastMessageAt, relativeTo: now, calendar: calendar)
            // Sort conversations within each group by lastMessageAt (newest first)
            groups[key, default: []].append(conversation)
        }
        
        // Sort each group internally by date (newest first)
        for key in groups.keys {
            groups[key]?.sort { $0.lastMessageAt > $1.lastMessageAt }
        }
        
        return groups
    }
    
    private func groupKey(for date: Date, relativeTo now: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day {
            if daysAgo < 7 {
                return "This Week"
            } else if daysAgo < 14 {
                return "Last Week"
            } else if daysAgo < 30 {
                return "This Month"
            } else {
                return "Earlier"
            }
        }
        return "Earlier"
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: SpotTheme.Spacing.sm) {
                // Type icon
                conversationIcon
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(conversation.title)
                            .font(SpotTheme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(SpotTheme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Active indicator for workouts
                        if conversation.isWorkout && conversation.isActive {
                            Circle()
                                .fill(SpotTheme.sage)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    HStack(spacing: SpotTheme.Spacing.xs) {
                        // Type badge
                        if conversation.isWorkout {
                            Text("Workout")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(SpotTheme.clay)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(SpotTheme.clay.opacity(0.15))
                                )
                        }
                        
                        Text(conversation.subtitle)
                            .font(SpotTheme.Typography.caption)
                            .foregroundStyle(SpotTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, SpotTheme.Spacing.md)
            .padding(.vertical, SpotTheme.Spacing.sm)
            .background(isSelected ? SpotTheme.clay.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Icon
    
    private var conversationIcon: some View {
        Circle()
            .fill(iconBackgroundColor)
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(iconForegroundColor)
            )
    }
    
    private var iconName: String {
        if conversation.isWorkout {
            return workoutIconName
        } else {
            return "bubble.left.fill"
        }
    }
    
    private var iconBackgroundColor: Color {
        if isSelected {
            return conversation.isWorkout ? SpotTheme.clay : SpotTheme.sage
        } else {
            return SpotTheme.textSecondary.opacity(0.1)
        }
    }
    
    private var iconForegroundColor: Color {
        if isSelected {
            return SpotTheme.onClay
        } else {
            return conversation.isWorkout ? SpotTheme.clay : SpotTheme.textSecondary
        }
    }
    
    private var workoutIconName: String {
        // All workouts use dumbbell icon for consistency
        return "dumbbell.fill"
    }
}

// MARK: - Preview

#Preview("History Panel") {
    WorkoutHistoryPanel(
        userProfile: nil,
        currentConversation: nil,
        onSelectConversation: { _ in },
        onNewChat: { },
        onDismiss: { },
        onOpenDashboard: { }
    )
    .modelContainer(SampleData.previewContainer)
}
