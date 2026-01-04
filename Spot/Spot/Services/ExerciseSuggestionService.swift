//
//  ExerciseSuggestionService.swift
//  Spot
//
//  Service to provide exercise suggestions based on workout type.
//  Maps workout types (push, pull, legs) to relevant muscle groups.
//

import Foundation
import SwiftData

@MainActor
class ExerciseSuggestionService {
    private let modelContext: ModelContext
    
    /// Maps workout type keywords to relevant muscle groups
    static let workoutTypeMapping: [String: [String]] = [
        // Push/Pull/Legs split
        "push": ["Chest", "Shoulders", "Arms"],
        "pull": ["Back", "Arms"],
        "legs": ["Legs"],
        "leg": ["Legs"],
        
        // Body part specific
        "chest": ["Chest"],
        "back": ["Back"],
        "shoulder": ["Shoulders"],
        "arm": ["Arms"],
        "bicep": ["Arms"],
        "tricep": ["Arms"],
        "core": ["Core"],
        "ab": ["Core"],
        
        // Upper/Lower split
        "upper": ["Chest", "Back", "Shoulders", "Arms"],
        "lower": ["Legs", "Core"],
        
        // Full body
        "full": ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
    ]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Get exercises relevant to a workout label
    /// - Parameters:
    ///   - workoutLabel: The workout session label (e.g., "Push Day", "Leg Day")
    ///   - limit: Maximum number of exercises to return
    ///   - excluding: Set of exercise names to exclude (exercises already done in the workout)
    /// - Returns: Array of relevant exercises, sorted by most recently used
    func getSuggestions(for workoutLabel: String, limit: Int = 6, excluding: Set<String> = []) -> [Exercise] {
        let muscleGroups = detectMuscleGroups(from: workoutLabel)
        guard !muscleGroups.isEmpty else { return [] }
        
        return fetchExercises(forMuscleGroups: muscleGroups, limit: limit, excluding: excluding)
    }
    
    /// Detect which muscle groups are relevant based on workout label
    private func detectMuscleGroups(from label: String) -> [String] {
        let lowercased = label.lowercased()
        var matchedGroups: Set<String> = []
        
        for (keyword, groups) in Self.workoutTypeMapping {
            if lowercased.contains(keyword) {
                groups.forEach { matchedGroups.insert($0) }
            }
        }
        
        return Array(matchedGroups)
    }
    
    /// Fetch exercises matching any of the given muscle groups
    private func fetchExercises(forMuscleGroups groups: [String], limit: Int, excluding: Set<String> = []) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        guard let allExercises = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        // Normalize excluded names for case-insensitive comparison
        let normalizedExcluded = Set(excluding.map { $0.lowercased() })
        
        // Filter to exercises matching the muscle groups and not in exclusion list
        let normalizedGroups = Set(groups.map { $0.lowercased() })
        let matching = allExercises.filter { exercise in
            let matchesGroup = normalizedGroups.contains(exercise.muscleGroup.lowercased())
            let isExcluded = normalizedExcluded.contains(exercise.name.lowercased())
            return matchesGroup && !isExcluded && !exercise.isHidden
        }
        
        // Sort by most recently performed (exercises with history first)
        let sorted = matching.sorted { ex1, ex2 in
            let date1 = ex1.lastPerformed?.session?.startTime ?? .distantPast
            let date2 = ex2.lastPerformed?.session?.startTime ?? .distantPast
            return date1 > date2
        }
        
        return Array(sorted.prefix(limit))
    }
    
    /// Check if a workout label has any matching muscle groups
    func hasRelevantExercises(for workoutLabel: String) -> Bool {
        let groups = detectMuscleGroups(from: workoutLabel)
        guard !groups.isEmpty else { return false }
        
        let exercises = fetchExercises(forMuscleGroups: groups, limit: 1)
        return !exercises.isEmpty
    }
}
