//
//  LoggedExerciseInfo.swift
//  Spot
//
//  Data structure for logged exercise display in chat.
//  Used to show inline confirmation cards when sets are logged.
//

import Foundation

/// Container for one or more logged exercises
struct LoggedExerciseInfo: Codable, Equatable, Sendable {
    let exercises: [ExerciseEntry]
    
    /// Single exercise entry
    struct ExerciseEntry: Codable, Equatable, Identifiable, Sendable {
        var id: String { exerciseName }
        let exerciseName: String
        let sets: [LoggedSetInfo]
        let isPR: Bool
        let previousBest: Double?
    }
    
    /// Single set info
    struct LoggedSetInfo: Codable, Equatable, Identifiable, Sendable {
        var id: String { "\(setNumber)-\(weight)-\(reps)" }
        let setNumber: Int
        let weight: Double
        let reps: Int
        let isPR: Bool
        
        /// Check if this is a bodyweight set
        var isBodyweight: Bool {
            weight == 0
        }
        
        var quickSummary: String {
            if isBodyweight {
                return weight > 0 ? "BW (\(Int(weight))) x \(reps)" : "BW x \(reps)"
            }
            return "\(Int(weight)) x \(reps)"
        }
    }
    
    /// Convenience: check if any exercise had a PR
    var hasPR: Bool {
        exercises.contains { $0.isPR }
    }
    
    /// Convenience: total number of exercises logged
    var exerciseCount: Int {
        exercises.count
    }
    
    /// Convenience: create from a single exercise (backward compatibility)
    static func single(
        exerciseName: String,
        sets: [LoggedSetInfo],
        isPR: Bool,
        previousBest: Double?
    ) -> LoggedExerciseInfo {
        LoggedExerciseInfo(exercises: [
            ExerciseEntry(
                exerciseName: exerciseName,
                sets: sets,
                isPR: isPR,
                previousBest: previousBest
            )
        ])
    }
}

