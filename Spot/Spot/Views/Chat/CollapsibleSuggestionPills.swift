//
//  CollapsibleSuggestionPills.swift
//  Spot
//
//  A wrapper for ExerciseSuggestionPills that adds collapse/expand functionality.
//  Shows a circular toggle button with chevron to hide/show the pills.
//

import SwiftUI

struct CollapsibleSuggestionPills: View {
    let exercises: [Exercise]
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onSelect: (Exercise) -> Void
    
    var body: some View {
        // Use frame with leading alignment to keep button on left when collapsed
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpotTheme.Spacing.sm) {
                    // Toggle button as first element in scroll
                    toggleButton
                    
                    // Pills (only when expanded)
                    if !isCollapsed {
                        ForEach(exercises) { exercise in
                            ExerciseSuggestionPill(exercise: exercise) {
                                onSelect(exercise)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .padding(.horizontal, SpotTheme.Spacing.md)
            }
            
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.25), value: isCollapsed)
    }
    
    // MARK: - Toggle Button
    
    private var toggleButton: some View {
        Button(action: onToggle) {
            Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SpotTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(toggleBackground)
        }
        .buttonStyle(PillButtonStyle())
    }
    
    private var toggleBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

// MARK: - Preview

#Preview("Collapsible Pills - Expanded") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            CollapsibleSuggestionPills(
                exercises: [
                    Exercise(name: "Bench Press", muscleGroup: "Chest"),
                    Exercise(name: "Incline Press", muscleGroup: "Chest"),
                    Exercise(name: "Cable Flyes", muscleGroup: "Chest"),
                    Exercise(name: "Overhead Press", muscleGroup: "Shoulders"),
                    Exercise(name: "Lateral Raises", muscleGroup: "Shoulders")
                ],
                isCollapsed: false,
                onToggle: { print("Toggle") },
                onSelect: { print("Selected: \($0.name)") }
            )
            .padding(.bottom, 80)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Collapsible Pills - Collapsed") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            CollapsibleSuggestionPills(
                exercises: [
                    Exercise(name: "Bench Press", muscleGroup: "Chest"),
                    Exercise(name: "Incline Press", muscleGroup: "Chest")
                ],
                isCollapsed: true,
                onToggle: { print("Toggle") },
                onSelect: { print("Selected: \($0.name)") }
            )
            .padding(.bottom, 80)
        }
    }
    .preferredColorScheme(.dark)
}
