//
//  QuickActionPills.swift
//  Spot
//
//  Horizontal scroll of pill-shaped action chips.
//  Quick shortcuts for common actions like "Start Workout", "History".
//

import SwiftUI

// MARK: - Quick Action Model

struct QuickAction: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
    let prompt: String  // The message to send when tapped
    
    static let startWorkout = QuickAction(
        title: "Start Workout",
        icon: "figure.strengthtraining.traditional",
        prompt: "Start a workout"
    )
    
    static let whatDidIDoLastTime = QuickAction(
        title: "Last Session",
        icon: "clock.arrow.circlepath",
        prompt: "What did I do last time?"
    )
    
    static let myPRs = QuickAction(
        title: "My PRs",
        icon: "trophy",
        prompt: "What are my personal records?"
    )
    
    static let history = QuickAction(
        title: "History",
        icon: "calendar",
        prompt: "Show my workout history"
    )
    
    static let defaultActions: [QuickAction] = [
        .startWorkout,
        .whatDidIDoLastTime,
        .myPRs,
        .history
    ]
}

// MARK: - Quick Action Pills View

struct QuickActionPills: View {
    let actions: [QuickAction]
    let onSelect: (QuickAction) -> Void
    
    init(
        actions: [QuickAction] = QuickAction.defaultActions,
        onSelect: @escaping (QuickAction) -> Void
    ) {
        self.actions = actions
        self.onSelect = onSelect
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpotTheme.Spacing.sm) {
                ForEach(actions) { action in
                    QuickActionPill(action: action) {
                        onSelect(action)
                    }
                }
            }
            .padding(.horizontal, SpotTheme.Spacing.md)
        }
    }
}

// MARK: - Individual Pill

struct QuickActionPill: View {
    let action: QuickAction
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpotTheme.Spacing.xs) {
                Image(systemName: action.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(action.title)
                    .font(SpotTheme.Typography.subheadline)
            }
            .foregroundStyle(SpotTheme.textPrimary)
            .padding(.horizontal, SpotTheme.Spacing.md)
            .padding(.vertical, SpotTheme.Spacing.xs)
            .warmGlassPill(style: .regular)
        }
        .buttonStyle(PillButtonStyle())
    }
}

// MARK: - Button Style

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Quick Action Pills") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            QuickActionPills { action in
                print("Selected: \(action.title)")
            }
            
            Spacer()
        }
    }
}

#Preview("Quick Action Pills - Dark") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            QuickActionPills { action in
                print("Selected: \(action.title)")
            }
            
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

