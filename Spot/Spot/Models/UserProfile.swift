//
//  UserProfile.swift
//  Spot
//
//  Stores user information for personalized experience.
//  Collected during onboarding flow.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// User's display name (required)
    var name: String
    
    /// User's height in inches (optional)
    var heightInches: Double?
    
    /// User's weight in pounds (optional)
    var weightLbs: Double?
    
    /// User's fitness goals (supports multi-select)
    var fitnessGoals: [String]
    
    /// When the profile was created
    var createdAt: Date
    
    /// Whether the user has completed onboarding
    var hasCompletedOnboarding: Bool
    
    // MARK: - Initialization
    
    init(
        name: String,
        heightInches: Double? = nil,
        weightLbs: Double? = nil,
        fitnessGoals: [String] = [],
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.heightInches = heightInches
        self.weightLbs = weightLbs
        self.fitnessGoals = fitnessGoals
        self.createdAt = Date()
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
    
    // MARK: - Computed Properties
    
    /// Formatted height string (e.g., "5'10\"")
    var formattedHeight: String? {
        guard let inches = heightInches else { return nil }
        let feet = Int(inches) / 12
        let remainingInches = Int(inches) % 12
        return "\(feet)'\(remainingInches)\""
    }
    
    /// Formatted weight string (e.g., "180 lbs")
    var formattedWeight: String? {
        guard let weight = weightLbs else { return nil }
        return "\(Int(weight)) lbs"
    }
    
    /// First name only (for greetings)
    var firstName: String {
        name.components(separatedBy: " ").first ?? name
    }
}

// MARK: - Fitness Goals

extension UserProfile {
    /// Common fitness goal options
    enum FitnessGoal: String, CaseIterable {
        case buildMuscle = "Build Muscle"
        case loseWeight = "Lose Weight"
        case gainStrength = "Gain Strength"
        case improveEndurance = "Improve Endurance"
        case stayActive = "Stay Active"
        case athletic = "Athletic Performance"
        
        var description: String {
            switch self {
            case .buildMuscle: return "Focus on hypertrophy and size"
            case .loseWeight: return "Burn fat while preserving muscle"
            case .gainStrength: return "Get stronger on compound lifts"
            case .improveEndurance: return "Build stamina and conditioning"
            case .stayActive: return "Maintain overall fitness"
            case .athletic: return "Sport-specific training"
            }
        }
    }
}

