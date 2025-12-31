//
//  WorkoutExercise.swift
//  Spot
//
//  Junction table connecting a WorkoutSession to an Exercise definition.
//  Represents a specific instance of an exercise performed during a workout.
//

import Foundation
import SwiftData

@Model
final class WorkoutExercise {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// User notes for this exercise instance (e.g., "Shoulder felt tight")
    var notes: String?
    
    /// Order of this exercise in the workout (1st, 2nd, 3rd...)
    var orderIndex: Int
    
    // MARK: - Relationships
    
    /// The parent workout session
    var session: WorkoutSession?
    
    /// Link to the master exercise definition
    var exercise: Exercise?
    
    /// The sets performed for this exercise (cascade delete)
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise)
    var sets: [WorkoutSet] = []
    
    // MARK: - Initialization
    
    init(
        orderIndex: Int,
        notes: String? = nil,
        session: WorkoutSession? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.notes = notes
        self.session = session
        self.exercise = exercise
    }
    
    // MARK: - Computed Properties
    
    /// Total volume for this exercise instance (sum of weight * reps for all sets)
    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
    
    /// Highest weight lifted in this exercise instance
    var maxWeight: Double {
        sets.map { $0.weight }.max() ?? 0
    }
    
    /// Total reps across all sets
    var totalReps: Int {
        sets.reduce(0) { $0 + $1.reps }
    }
    
    /// Sets sorted by set number
    var orderedSets: [WorkoutSet] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }
    
    /// Whether any set in this exercise was a PR
    var hasPR: Bool {
        sets.contains { $0.isPR }
    }
    
    /// Quick summary string (e.g., "3 sets • 185 lbs max")
    var quickSummary: String {
        let setCount = sets.count
        let maxWt = maxWeight
        
        if maxWt > 0 {
            return "\(setCount) sets • \(Int(maxWt)) lbs max"
        } else {
            return "\(setCount) sets"
        }
    }
}

