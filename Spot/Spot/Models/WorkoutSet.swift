//
//  WorkoutSet.swift
//  Spot
//
//  The atomic unit of work - a single set of an exercise.
//  Contains weight, reps, and optional RPE.
//

import Foundation
import SwiftData

@Model
final class WorkoutSet {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// Set number in the exercise (1, 2, 3...)
    var setNumber: Int
    
    /// Weight lifted in pounds
    var weight: Double
    
    /// Number of repetitions
    var reps: Int
    
    /// Rate of Perceived Exertion (1-10), optional
    var rpe: Int?
    
    /// Flag indicating if this set broke a personal record
    var isPR: Bool
    
    /// Timestamp when this set was logged
    var timestamp: Date
    
    // MARK: - Relationships
    
    /// Parent exercise instance
    var workoutExercise: WorkoutExercise?
    
    // MARK: - Initialization
    
    init(
        setNumber: Int,
        weight: Double,
        reps: Int,
        rpe: Int? = nil,
        isPR: Bool = false,
        timestamp: Date = Date(),
        workoutExercise: WorkoutExercise? = nil
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.isPR = isPR
        self.timestamp = timestamp
        self.workoutExercise = workoutExercise
    }
    
    // MARK: - Computed Properties
    
    /// Whether this is a bodyweight exercise (weight is 0)
    var isBodyweight: Bool {
        weight == 0
    }
    
    /// Volume for this set (weight * reps)
    var volume: Double {
        weight * Double(reps)
    }
    
    /// Formatted weight string (e.g., "185 lbs" or "BW")
    var formattedWeight: String {
        isBodyweight ? "BW" : "\(Int(weight)) lbs"
    }
    
    /// Quick summary string (e.g., "185 x 8" or "BW x 8")
    var quickSummary: String {
        if isBodyweight {
            return "BW x \(reps)"
        }
        return "\(Int(weight)) x \(reps)"
    }
    
    /// Full summary including RPE if available (e.g., "185 x 8 @ RPE 8")
    var fullSummary: String {
        if let rpe = rpe {
            if isBodyweight {
                return "BW x \(reps) @ RPE \(rpe)"
            }
            return "\(Int(weight)) x \(reps) @ RPE \(rpe)"
        }
        return quickSummary
    }
}

