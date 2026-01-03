//
//  AppearanceMode.swift
//  Spot
//
//  Defines the app's appearance mode options for user preference.
//

import SwiftUI

/// Represents the user's preferred appearance mode for the app
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    /// Convert to SwiftUI ColorScheme (nil means follow system)
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    /// Icon for the appearance mode
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
    /// Description for the appearance mode
    var description: String {
        switch self {
        case .system:
            return "Match device settings"
        case .light:
            return "Always use light theme"
        case .dark:
            return "Always use dark theme"
        }
    }
}
