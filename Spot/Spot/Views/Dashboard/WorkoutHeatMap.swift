//
//  WorkoutHeatMap.swift
//  Spot
//
//  GitHub-style heat map showing workout activity.
//  Color intensity based on number of exercises per day.
//

import SwiftUI

struct WorkoutHeatMap: View {
    let sessions: [WorkoutSession]
    
    // State
    @State private var selectedDate: Date?
    @State private var currentMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
            // Header
            HStack {
                Text("Activity")
                    .font(SpotTheme.Typography.headline)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Spacer()
                
                // Month navigation
                HStack(spacing: SpotTheme.Spacing.sm) {
                    Button {
                        withAnimation {
                            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                    
                    Text(monthYearString)
                        .font(SpotTheme.Typography.subheadline)
                        .foregroundStyle(SpotTheme.textSecondary)
                        .frame(minWidth: 100)
                    
                    Button {
                        withAnimation {
                            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                    .disabled(calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month))
                }
            }
            
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                        .frame(height: 20)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            intensity: intensity(for: date),
                            isSelected: selectedDate == date,
                            isToday: calendar.isDateInToday(date)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = selectedDate == date ? nil : date
                            }
                        }
                    } else {
                        // Empty cell for padding
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
            
            // Selected date details
            if let selected = selectedDate {
                selectedDateDetails(for: selected)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Legend
            legendView
        }
        .padding(SpotTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SpotTheme.Radius.medium, style: .continuous)
                .fill(SpotTheme.textPrimary.opacity(0.03))
        )
    }
    
    // MARK: - Computed Properties
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        var days: [Date?] = []
        
        // Add empty cells for days before the first of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add the days of the month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // MARK: - Data
    
    private func intensity(for date: Date) -> Double {
        let exerciseCount = exercisesOnDate(date)
        if exerciseCount == 0 { return 0 }
        if exerciseCount <= 2 { return 0.25 }
        if exerciseCount <= 4 { return 0.5 }
        if exerciseCount <= 6 { return 0.75 }
        return 1.0
    }
    
    private func exercisesOnDate(_ date: Date) -> Int {
        sessions
            .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .reduce(0) { $0 + $1.exercises.count }
    }
    
    private func sessionsOnDate(_ date: Date) -> [WorkoutSession] {
        sessions.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    
    // MARK: - Views
    
    @ViewBuilder
    private func selectedDateDetails(for date: Date) -> some View {
        let daySessions = sessionsOnDate(date)
        let totalExercises = daySessions.reduce(0) { $0 + $1.exercises.count }
        
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.xs) {
            Divider()
                .padding(.vertical, SpotTheme.Spacing.xs)
            
            HStack {
                Text(formattedDate(date))
                    .font(SpotTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Spacer()
                
                if daySessions.isEmpty {
                    Text("Rest day")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                } else {
                    Text("\(daySessions.count) workout\(daySessions.count == 1 ? "" : "s"), \(totalExercises) exercise\(totalExercises == 1 ? "" : "s")")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
            }
            
            if !daySessions.isEmpty {
                ForEach(daySessions, id: \.id) { session in
                    HStack(spacing: SpotTheme.Spacing.xs) {
                        Circle()
                            .fill(SpotTheme.sage)
                            .frame(width: 6, height: 6)
                        
                        Text(session.label)
                            .font(SpotTheme.Typography.caption)
                            .foregroundStyle(SpotTheme.textPrimary)
                        
                        Text("• \(session.exercises.count) exercises")
                            .font(SpotTheme.Typography.caption)
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                }
            }
        }
    }
    
    private var legendView: some View {
        HStack(spacing: SpotTheme.Spacing.sm) {
            Spacer()
            
            Text("Less")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary)
            
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(intensity == 0 ? SpotTheme.textPrimary.opacity(0.1) : SpotTheme.sage.opacity(intensity))
                    .frame(width: 12, height: 12)
            }
            
            Text("More")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary)
        }
        .padding(.top, SpotTheme.Spacing.xs)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let intensity: Double
    let isSelected: Bool
    let isToday: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            // Background based on intensity
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
            
            // Day number
            Text("\(calendar.component(.day, from: date))")
                .font(SpotTheme.Typography.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(textColor)
        }
        .frame(height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? SpotTheme.clay : Color.clear, lineWidth: 2)
        )
    }
    
    private var backgroundColor: Color {
        if intensity == 0 {
            return SpotTheme.textPrimary.opacity(0.05)
        }
        return SpotTheme.sage.opacity(intensity * 0.8 + 0.2)
    }
    
    private var textColor: Color {
        if intensity > 0.5 {
            return .white
        }
        return SpotTheme.textPrimary
    }
}

// MARK: - Preview

#Preview("Heat Map") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        WorkoutHeatMap(sessions: [])
            .padding()
    }
}

