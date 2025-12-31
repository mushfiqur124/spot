//
//  WarmGlassModifier.swift
//  Spot
//
//  Reusable glass effect modifier that adapts to light/dark mode.
//  Light mode: High-opacity frosted glass
//  Dark mode: Low-opacity stealth glass
//

import SwiftUI

// MARK: - Glass Style

enum GlassStyle {
    case regular      // Standard glass for cards, input fields
    case subtle       // Very subtle glass for AI bubbles
    case prominent    // More visible glass for floating elements
}

// MARK: - Warm Glass Modifier

struct WarmGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    let style: GlassStyle
    let cornerRadius: CGFloat
    
    init(style: GlassStyle = .regular, cornerRadius: CGFloat = SpotTheme.Radius.medium) {
        self.style = style
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        switch colorScheme {
        case .light:
            lightModeGlass
        case .dark:
            darkModeGlass
        @unknown default:
            lightModeGlass
        }
    }
    
    // Light mode: Frosted glass with high opacity white tint
    @ViewBuilder
    private var lightModeGlass: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(lightOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
            )
    }
    
    // Dark mode: Stealth glass with low opacity tint
    @ViewBuilder
    private var darkModeGlass: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(darkOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
    
    private var lightOpacity: Double {
        switch style {
        case .regular: return 0.7
        case .subtle: return 0.5
        case .prominent: return 0.85
        }
    }
    
    private var darkOpacity: Double {
        switch style {
        case .regular: return 0.08
        case .subtle: return 0.04
        case .prominent: return 0.12
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply warm glass effect
    func warmGlass(
        style: GlassStyle = .regular,
        cornerRadius: CGFloat = SpotTheme.Radius.medium
    ) -> some View {
        self.modifier(WarmGlassModifier(style: style, cornerRadius: cornerRadius))
    }
    
    /// Apply pill-shaped warm glass effect
    func warmGlassPill(style: GlassStyle = .regular) -> some View {
        self.modifier(WarmGlassModifier(style: style, cornerRadius: SpotTheme.Radius.pill))
    }
}

// MARK: - Preview

#Preview("Glass Styles") {
    ZStack {
        // Background
        SpotTheme.Raw.canvasLight
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            Text("Regular Glass")
                .padding()
                .warmGlass(style: .regular)
            
            Text("Subtle Glass")
                .padding()
                .warmGlass(style: .subtle)
            
            Text("Prominent Glass")
                .padding()
                .warmGlass(style: .prominent)
            
            Text("Pill Glass")
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .warmGlassPill()
        }
        .foregroundStyle(SpotTheme.Raw.textPrimaryLight)
    }
}

#Preview("Glass Styles - Dark") {
    ZStack {
        // Background
        SpotTheme.Raw.canvasDark
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            Text("Regular Glass")
                .padding()
                .warmGlass(style: .regular)
            
            Text("Subtle Glass")
                .padding()
                .warmGlass(style: .subtle)
            
            Text("Prominent Glass")
                .padding()
                .warmGlass(style: .prominent)
            
            Text("Pill Glass")
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .warmGlassPill()
        }
        .foregroundStyle(SpotTheme.Raw.textPrimaryDark)
    }
    .preferredColorScheme(.dark)
}

