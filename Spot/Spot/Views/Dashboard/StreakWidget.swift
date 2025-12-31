//
//  StreakWidget.swift
//  Spot
//
//  Widget showing workout streak - consecutive days with workouts.
//  Includes current streak and best all-time streak.
//

import SwiftUI

struct StreakWidget: View {
    let sessions: [WorkoutSession]
    
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: SpotTheme.Spacing.md) {
            // Current Streak
            streakCard(
                title: "Current Streak",
                value: currentStreak,
                icon: "flame.fill",
                iconColor: currentStreak > 0 ? SpotTheme.clay : SpotTheme.textSecondary.opacity(0.5),
                message: currentStreakMessage
            )
            
            // Best Streak
            streakCard(
                title: "Best Streak",
                value: bestStreak,
                icon: "trophy.fill",
                iconColor: bestStreak > 0 ? SpotTheme.sage : SpotTheme.textSecondary.opacity(0.5),
                message: bestStreakMessage
            )
        }
    }
    
    // MARK: - Streak Card
    
    private func streakCard(title: String, value: Int, icon: String, iconColor: Color, message: String) -> some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                
                Text(title)
                    .font(SpotTheme.Typography.caption)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: SpotTheme.Spacing.xxs) {
                Text("\(value)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Text("day\(value == 1 ? "" : "s")")
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            Text(message)
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpotTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SpotTheme.Radius.medium, style: .continuous)
                .fill(SpotTheme.textPrimary.opacity(0.03))
        )
    }
    
    // MARK: - Streak Calculations
    
    /// Calculate current streak (consecutive days ending today or yesterday)
    private var currentStreak: Int {
        let workoutDates = uniqueWorkoutDates
        guard !workoutDates.isEmpty else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // Check if the streak is still active (last workout was today or yesterday)
        guard let lastWorkout = workoutDates.first,
              lastWorkout >= yesterday else { return 0 }
        
        var streak = 0
        var checkDate = lastWorkout
        
        for date in workoutDates {
            if calendar.isDate(date, inSameDayAs: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else if date < checkDate {
                break
            }
        }
        
        return streak
    }
    
    /// Calculate best streak ever
    private var bestStreak: Int {
        let workoutDates = uniqueWorkoutDates
        guard workoutDates.count > 0 else { return 0 }
        
        var maxStreak = 1
        var currentStreakCount = 1
        
        for i in 1..<workoutDates.count {
            let expectedPrevDate = calendar.date(byAdding: .day, value: -1, to: workoutDates[i-1])!
            
            if calendar.isDate(workoutDates[i], inSameDayAs: expectedPrevDate) {
                currentStreakCount += 1
                maxStreak = max(maxStreak, currentStreakCount)
            } else {
                currentStreakCount = 1
            }
        }
        
        return maxStreak
    }
    
    /// Get unique workout dates, sorted newest first
    private var uniqueWorkoutDates: [Date] {
        let dates = sessions.map { calendar.startOfDay(for: $0.startTime) }
        let uniqueDates = Array(Set(dates))
        return uniqueDates.sorted(by: >)
    }
    
    // MARK: - Messages
    
    private var currentStreakMessage: String {
        switch currentStreak {
        case 0:
            return "Start a workout today!"
        case 1:
            return "Good start! Keep going!"
        case 2...3:
            return "Building momentum!"
        case 4...6:
            return "You're on fire!"
        case 7...13:
            return "One week strong!"
        case 14...29:
            return "Two weeks! Incredible!"
        case 30...59:
            return "A whole month! Legend!"
        default:
            return "Unstoppable!"
        }
    }
    
    private var bestStreakMessage: String {
        switch bestStreak {
        case 0:
            return "No streaks yet"
        case 1:
            return "Room to grow!"
        case 2...6:
            return "Nice foundation!"
        case 7...13:
            return "Solid week!"
        case 14...29:
            return "Great consistency!"
        case 30...59:
            return "Month warrior!"
        default:
            return "True dedication!"
        }
    }
}

// MARK: - Preview

#Preview("Streak Widget") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            StreakWidget(sessions: [])
        }
        .padding()
    }
}

