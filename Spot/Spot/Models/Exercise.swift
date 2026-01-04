//
//  Exercise.swift
//  Spot
//
//  Master definition for an exercise movement.
//  Acts as the single source of truth - all workout instances link back here.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// The standardized name (e.g., "Incline Bench Press")
    /// This should be unique across all exercises
    @Attribute(.unique) var name: String
    
    /// Primary muscle group (e.g., "Chest", "Back", "Legs")
    var muscleGroup: String
    
    /// Cached personal record for quick lookup (highest weight ever lifted)
    var allTimeMaxWeight: Double?
    
    /// Cached max volume (Weight * Reps) for a single set
    var allTimeMaxVolume: Double?
    
    /// Whether the user has "soft deleted" (hidden) this exercise
    var isHidden: Bool = false
    
    // MARK: - Relationships
    
    /// All instances of this exercise ever performed (inverse relationship)
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var history: [WorkoutExercise] = []
    
    // MARK: - Initialization
    
    init(
        name: String,
        muscleGroup: String,
        allTimeMaxWeight: Double? = nil,
        allTimeMaxVolume: Double? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.allTimeMaxWeight = allTimeMaxWeight
        self.allTimeMaxVolume = allTimeMaxVolume
    }
    
    // MARK: - Computed Properties
    
    /// Returns the total number of times this exercise has been performed
    var totalSessions: Int {
        history.count
    }
    
    /// Returns the most recent workout instance of this exercise
    var lastPerformed: WorkoutExercise? {
        history
            .sorted { ($0.session?.startTime ?? .distantPast) > ($1.session?.startTime ?? .distantPast) }
            .first
    }
}

