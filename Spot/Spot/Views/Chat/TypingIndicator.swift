//
//  TypingIndicator.swift
//  Spot
//
//  Animated dots indicator for when AI is "thinking" or streaming.
//

import SwiftUI

struct TypingIndicator: View {
    @State private var dot1Offset: CGFloat = 0
    @State private var dot2Offset: CGFloat = 0
    @State private var dot3Offset: CGFloat = 0
    
    private let dotSize: CGFloat = 8
    private let bounceHeight: CGFloat = -6
    private let animationDuration: Double = 0.4
    
    var body: some View {
        HStack(alignment: .bottom, spacing: SpotTheme.Spacing.xs) {
            Spacer(minLength: 0)
                .frame(maxWidth: 0)
            
            HStack(spacing: 5) {
                dot(offset: dot1Offset)
                dot(offset: dot2Offset)
                dot(offset: dot3Offset)
            }
            .padding(.horizontal, SpotTheme.Spacing.md)
            .padding(.vertical, SpotTheme.Spacing.sm + 4)
            .warmGlass(style: .subtle, cornerRadius: SpotTheme.Radius.bubble)
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, SpotTheme.Spacing.md)
        .onAppear {
            startAnimation()
        }
    }
    
    private func dot(offset: CGFloat) -> some View {
        Circle()
            .fill(SpotTheme.textSecondary)
            .frame(width: dotSize, height: dotSize)
            .offset(y: offset)
    }
    
    private func startAnimation() {
        // Staggered bouncing animation
        withAnimation(
            Animation
                .easeInOut(duration: animationDuration)
                .repeatForever(autoreverses: true)
        ) {
            dot1Offset = bounceHeight
        }
        
        withAnimation(
            Animation
                .easeInOut(duration: animationDuration)
                .repeatForever(autoreverses: true)
                .delay(0.15)
        ) {
            dot2Offset = bounceHeight
        }
        
        withAnimation(
            Animation
                .easeInOut(duration: animationDuration)
                .repeatForever(autoreverses: true)
                .delay(0.30)
        ) {
            dot3Offset = bounceHeight
        }
    }
}

// MARK: - Preview

#Preview("Typing Indicator") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            TypingIndicator()
            Spacer()
        }
        .padding(.top, 100)
    }
}

#Preview("Typing Indicator - Dark") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        VStack {
            TypingIndicator()
            Spacer()
        }
        .padding(.top, 100)
    }
    .preferredColorScheme(.dark)
}
