//
//  ExerciseSuggestionPills.swift
//  Spot
//
//  Horizontal scroll of exercise suggestion badges.
//  Shows relevant exercises based on the current workout type.
//

import SwiftUI

struct ExerciseSuggestionPills: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpotTheme.Spacing.sm) {
                ForEach(exercises) { exercise in
                    ExerciseSuggestionPill(exercise: exercise) {
                        onSelect(exercise)
                    }
                }
            }
            .padding(.horizontal, SpotTheme.Spacing.md)
        }
    }
}

// MARK: - Individual Pill

struct ExerciseSuggestionPill: View {
    let exercise: Exercise
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(exercise.name)
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textPrimary)
                .padding(.horizontal, SpotTheme.Spacing.md)
                .padding(.vertical, SpotTheme.Spacing.xs)
                .warmGlassPill(style: .regular)
        }
        .buttonStyle(PillButtonStyle())
    }
}

// MARK: - Preview

#Preview("Exercise Suggestion Pills") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            ExerciseSuggestionPills(
                exercises: [
                    Exercise(name: "Bench Press", muscleGroup: "Chest"),
                    Exercise(name: "Incline Dumbbell Press", muscleGroup: "Chest"),
                    Exercise(name: "Cable Flyes", muscleGroup: "Chest"),
                    Exercise(name: "Overhead Press", muscleGroup: "Shoulders")
                ]
            ) { exercise in
                print("Selected: \(exercise.name)")
            }
            
            Spacer()
        }
    }
}

#Preview("Exercise Suggestion Pills - Dark") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            ExerciseSuggestionPills(
                exercises: [
                    Exercise(name: "Pull-ups", muscleGroup: "Back"),
                    Exercise(name: "Barbell Rows", muscleGroup: "Back"),
                    Exercise(name: "Lat Pulldowns", muscleGroup: "Back")
                ]
            ) { exercise in
                print("Selected: \(exercise.name)")
            }
            
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
