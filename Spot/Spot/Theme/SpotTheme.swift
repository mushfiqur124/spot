//
//  SpotTheme.swift
//  Spot
//
//  Editorial design system with adaptive light/dark colors.
//  Premium, warm aesthetic - like a smart digital notebook.
//

import SwiftUI

// MARK: - Color Extension

extension Color {
    /// Initialize color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Spot Theme

enum SpotTheme {
    
    // MARK: - Semantic Colors
    
    /// App background - Cream (light) / Deep Espresso (dark)
    static let canvas = Color("Canvas")
    
    /// Primary text - Soft Charcoal (light) / Off-White (dark)
    static let textPrimary = Color("TextPrimary")
    
    /// Secondary text - lighter variant
    static let textSecondary = Color("TextSecondary")
    
    /// User bubbles and active states - Muted Clay
    static let clay = Color("Clay")
    
    /// Success states and PRs - Sage Green
    static let sage = Color("Sage")
    
    /// Glass tint color (adapts per color scheme)
    static let glassTint = Color("GlassTint")
    
    // MARK: - Fixed Colors (Don't adapt)
    
    /// Pure white for text on clay backgrounds
    static let onClay = Color.white
    
    /// Muted Clay - #C27A59
    static let clayFixed = Color(hex: "C27A59")
    
    /// Sage Green - #8FA893
    static let sageFixed = Color(hex: "8FA893")
    
    // MARK: - Raw Color Values (for reference)
    
    enum Raw {
        // Light mode
        static let canvasLight = Color(hex: "FDFCF8")      // Cream
        static let textPrimaryLight = Color(hex: "2D2D2D") // Soft Charcoal
        static let textSecondaryLight = Color(hex: "6B6B6B")
        
        // Dark mode
        static let canvasDark = Color(hex: "151515")       // Deep Espresso
        static let textPrimaryDark = Color(hex: "E5E5E5")  // Off-White
        static let textSecondaryDark = Color(hex: "9A9A9A")
        
        // Accent colors (same in both modes)
        static let clay = Color(hex: "C27A59")             // Muted Clay
        static let sage = Color(hex: "8FA893")             // Sage Green
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let pill: CGFloat = 100
        static let bubble: CGFloat = 20
    }
    
    // MARK: - Shadows
    
    enum Shadow {
        static let subtle = ShadowStyle(
            color: Color.black.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
        
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 16,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extension for Theme

extension View {
    /// Apply subtle shadow
    func spotShadow(_ style: ShadowStyle = SpotTheme.Shadow.subtle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

