//
//  DashboardView.swift
//  Spot
//
//  Main dashboard view with workout analytics widgets.
//  Shows heatmap, progression charts, streak, and exercise history.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let userProfile: UserProfile?
    let onDismiss: () -> Void
    
    // Data
    @State private var workoutSessions: [WorkoutSession] = []
    @State private var exercises: [Exercise] = []
    
    var body: some View {
        ZStack {
            // Background
            SpotTheme.canvas
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Scrollable content
                ScrollView {
                    LazyVStack(spacing: SpotTheme.Spacing.lg) {
                        // Streak Widget
                        StreakWidget(sessions: workoutSessions)
                        
                        // Heat Map
                        WorkoutHeatMap(sessions: workoutSessions)
                        
                        // Progression Chart
                        ProgressionChart(exercises: exercises, sessions: workoutSessions)
                        
                        // Exercise History
                        ExerciseHistoryList(exercises: exercises)
                    }
                    .padding(.horizontal, SpotTheme.Spacing.md)
                    .padding(.vertical, SpotTheme.Spacing.md)
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SpotTheme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard")
                    .font(SpotTheme.Typography.title2)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                if let profile = userProfile {
                    Text("Your progress, \(profile.firstName)")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, SpotTheme.Spacing.sm)
        .padding(.vertical, SpotTheme.Spacing.sm)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        // Load all workout sessions
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        workoutSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []
        
        // Load all exercises with history
        let exerciseDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { !$0.isHidden },
            sortBy: [SortDescriptor(\.name)]
        )
        exercises = (try? modelContext.fetch(exerciseDescriptor)) ?? []
    }
}

// MARK: - Preview

#Preview("Dashboard") {
    DashboardView(
        userProfile: nil,
        onDismiss: {}
    )
    .modelContainer(SampleData.previewContainer)
}

