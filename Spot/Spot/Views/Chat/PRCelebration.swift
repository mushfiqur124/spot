//
//  PRCelebration.swift
//  Spot
//
//  Celebration animation for when user hits a new Personal Record.
//  Subtle sage-colored glow effect.
//

import SwiftUI

struct PRCelebration: View {
    @State private var isAnimating = false
    @State private var showCheckmark = false
    
    var body: some View {
        ZStack {
            // Expanding rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(SpotTheme.sage.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                    .scaleEffect(isAnimating ? 1.5 + CGFloat(index) * 0.3 : 0.5)
                    .opacity(isAnimating ? 0 : 1)
            }
            
            // Center checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SpotTheme.sage)
                .scaleEffect(showCheckmark ? 1 : 0)
                .opacity(showCheckmark ? 1 : 0)
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - PR Badge (inline in message)

struct PRBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: SpotTheme.Spacing.xxs) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 12))
            
            Text("NEW PR!")
                .font(SpotTheme.Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(SpotTheme.sage)
        .padding(.horizontal, SpotTheme.Spacing.sm)
        .padding(.vertical, SpotTheme.Spacing.xxs)
        .background(
            Capsule()
                .fill(SpotTheme.sage.opacity(0.15))
        )
        .scaleEffect(isAnimating ? 1.0 : 0.8)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - New Badge (inline in message)

struct NewExerciseBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: SpotTheme.Spacing.xxs) {
            Text("NEW")
                .font(SpotTheme.Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(SpotTheme.sage)
        .padding(.horizontal, SpotTheme.Spacing.sm)
        .padding(.vertical, SpotTheme.Spacing.xxs)
        .background(
            Capsule()
                .fill(SpotTheme.sage.opacity(0.15))
        )
        .scaleEffect(isAnimating ? 1.0 : 0.8)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview("PR Celebration") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        PRCelebration()
    }
}

#Preview("PR Badge") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            PRBadge()
            NewExerciseBadge()
        }
    }
}
