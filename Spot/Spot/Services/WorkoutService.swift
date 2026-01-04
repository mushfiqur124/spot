//
//  WorkoutService.swift
//  Spot
//
//  Core service for managing workouts, exercises, and sets.
//  Handles CRUD operations, PR detection, and history queries.
//

import Foundation
import SwiftData

/// Result returned when logging a set (includes PR information)
struct LogSetResult {
    let set: WorkoutSet
    let isPR: Bool
    let previousBest: Double?
    let exercise: Exercise
}

/// Entry for exercise history across sessions
struct ExerciseHistoryEntry {
    let date: Date
    let sets: [SetEntry]
    let maxWeight: Double
    let bestRepsAtMaxWeight: Int
    
    struct SetEntry {
        let weight: Double
        let reps: Int
    }
}

/// Result returned when fetching all PRs
struct AllPRsResult {
    let prs: [PREntry]
    let totalCount: Int
    
    struct PREntry {
        let exerciseName: String
        let weight: Double
        let volume: Double
        let muscleGroup: String
    }
}

/// Result returned when editing a set
struct EditSetResult {
    let exerciseName: String
    let setNumber: Int
    let weight: Double
    let reps: Int
}

/// Result returned when deleting a set
struct DeleteSetResult {
    let exerciseName: String
    let setNumber: Int
}

@MainActor
class WorkoutService {
    private let modelContext: ModelContext
    private let matchingService: ExerciseMatchingService
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.matchingService = ExerciseMatchingService(modelContext: modelContext)
    }
    
    // MARK: - Session Management
    
    /// Start a new workout session
    /// - Parameter label: The workout type (e.g., "Push Day", "Legs")
    /// - Returns: The newly created session
    func startSession(label: String) -> WorkoutSession {
        // End any currently active sessions first
        endAllActiveSessions()
        
        let session = WorkoutSession(label: label)
        modelContext.insert(session)
        return session
    }
    
    /// End a workout session
    /// - Parameter session: The session to end
    func endSession(_ session: WorkoutSession) {
        session.endTime = Date()
    }
    
    /// Get the currently active session (if any)
    func getActiveSession() -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.endTime == nil
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    /// End all active sessions
    private func endAllActiveSessions() {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.endTime == nil
            }
        )
        
        if let activeSessions = try? modelContext.fetch(descriptor) {
            for session in activeSessions {
                session.endTime = Date()
            }
        }
    }
    
    // MARK: - Exercise & Set Logging
    
    /// Log a set for an exercise in the current session
    /// - Parameters:
    ///   - exerciseName: Name of the exercise
    ///   - weight: Weight in pounds (0 for bodyweight exercises)
    ///   - reps: Number of repetitions
    ///   - rpe: Rate of Perceived Exertion (optional, 1-10)
    ///   - muscleGroup: Muscle group for new exercises
    ///   - session: The workout session (uses active session if nil)
    ///   - isBodyweight: Whether this is a bodyweight exercise
    /// - Returns: Result containing the set and PR information
    func logSet(
        exerciseName: String,
        weight: Double,
        reps: Int,
        rpe: Int? = nil,
        muscleGroup: String = "Other",
        session: WorkoutSession? = nil,
        isBodyweight: Bool = false
    ) -> LogSetResult? {
        // Get or create the session
        guard let activeSession = session ?? getActiveSession() else {
            return nil
        }
        
        // Convert BW exercises to use actual body weight
        var actualWeight = weight
        if isBodyweight && weight == 0 {
            actualWeight = getUserBodyWeight() ?? 0
        }
        
        // Find or create the exercise definition
        let exercise = matchingService.findOrCreate(name: exerciseName, muscleGroup: muscleGroup)
        
        // Find or create the workout exercise instance for this session
        let workoutExercise = findOrCreateWorkoutExercise(
            for: exercise,
            in: activeSession
        )
        
        // Determine set number
        let setNumber = workoutExercise.sets.count + 1
        
        // Check for PR
        let previousBest = exercise.allTimeMaxWeight
        let isPR = checkAndUpdatePR(exercise: exercise, weight: actualWeight, reps: reps)
        
        // Create the set
        let newSet = WorkoutSet(
            setNumber: setNumber,
            weight: actualWeight,
            reps: reps,
            rpe: rpe,
            isPR: isPR,
            workoutExercise: workoutExercise
        )
        
        modelContext.insert(newSet)
        workoutExercise.sets.append(newSet)
        
        return LogSetResult(
            set: newSet,
            isPR: isPR,
            previousBest: previousBest,
            exercise: exercise
        )
    }
    
    /// Get the user's body weight from their profile
    /// - Returns: User's weight in pounds, or nil if not set
    private func getUserBodyWeight() -> Double? {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? modelContext.fetch(descriptor).first else {
            return nil
        }
        return profile.weightLbs
    }
    
    /// Find or create a WorkoutExercise for a given Exercise in a session
    private func findOrCreateWorkoutExercise(
        for exercise: Exercise,
        in session: WorkoutSession
    ) -> WorkoutExercise {
        // Check if we already have this exercise in the session
        if let existing = session.exercises.first(where: { $0.exercise?.id == exercise.id }) {
            return existing
        }
        
        // Create new workout exercise
        let orderIndex = session.exercises.count
        let workoutExercise = WorkoutExercise(
            orderIndex: orderIndex,
            session: session,
            exercise: exercise
        )
        
        modelContext.insert(workoutExercise)
        session.exercises.append(workoutExercise)
        exercise.history.append(workoutExercise)
        
        return workoutExercise
    }
    
    // MARK: - PR Management
    
    /// Check if weight is a PR and update if so
    /// - Returns: true if this is a new PR
    private func checkAndUpdatePR(exercise: Exercise, weight: Double, reps: Int) -> Bool {
        let volume = weight * Double(reps)
        var isPR = false
        
        // Check weight PR
        if let currentMax = exercise.allTimeMaxWeight {
            if weight > currentMax {
                exercise.allTimeMaxWeight = weight
                isPR = true
            }
        } else {
            exercise.allTimeMaxWeight = weight
            isPR = true
        }
        
        // Check volume PR
        if let currentMaxVolume = exercise.allTimeMaxVolume {
            if volume > currentMaxVolume {
                exercise.allTimeMaxVolume = volume
            }
        } else {
            exercise.allTimeMaxVolume = volume
        }
        
        return isPR
    }
    
    /// Get the personal record for an exercise
    func getPR(exerciseName: String) -> (weight: Double, volume: Double)? {
        let result = matchingService.findBestMatch(for: exerciseName)
        guard let exercise = result.exercise, result.confidence >= matchingService.fuzzyMatchThreshold else { return nil }
        
        return (
            weight: exercise.allTimeMaxWeight ?? 0,
            volume: exercise.allTimeMaxVolume ?? 0
        )
    }
    
    /// Get all personal records across exercises
    /// - Parameters:
    ///   - limit: Maximum number of PRs to return
    ///   - muscleGroup: Optional filter by muscle group
    /// - Returns: Array of PRs and total count
    func getAllPRs(limit: Int = 5, muscleGroup: String? = nil) -> AllPRsResult {
        var descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.allTimeMaxWeight, order: .reverse)]
        )
        
        guard let allExercises = try? modelContext.fetch(descriptor) else {
            return AllPRsResult(prs: [], totalCount: 0)
        }
        
        // Filter to exercises with PRs
        var exercisesWithPRs = allExercises.filter { ($0.allTimeMaxWeight ?? 0) > 0 }
        
        // Filter by muscle group if specified
        if let group = muscleGroup?.lowercased() {
            exercisesWithPRs = exercisesWithPRs.filter { 
                $0.muscleGroup.lowercased().contains(group) 
            }
        }
        
        let totalCount = exercisesWithPRs.count
        
        // Build PR entries
        let prs: [AllPRsResult.PREntry] = exercisesWithPRs.prefix(limit).map { exercise in
            AllPRsResult.PREntry(
                exerciseName: exercise.name,
                weight: exercise.allTimeMaxWeight ?? 0,
                volume: exercise.allTimeMaxVolume ?? 0,
                muscleGroup: exercise.muscleGroup
            )
        }
        
        return AllPRsResult(prs: prs, totalCount: totalCount)
    }
    
    // MARK: - History Queries
    
    /// Get recent workout sessions
    /// - Parameter limit: Maximum number of sessions to return
    /// - Returns: Array of recent sessions, newest first
    func getRecentSessions(limit: Int = 5) -> [WorkoutSession] {
        var descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Get the last time a specific exercise was performed
    func getLastExerciseStats(exerciseName: String) -> WorkoutExercise? {
        let result = matchingService.findBestMatch(for: exerciseName)
        guard result.confidence >= matchingService.fuzzyMatchThreshold else { return nil }
        return result.exercise?.lastPerformed
    }
    
    /// Get exercise history across multiple sessions
    func getExerciseHistory(exerciseName: String, limit: Int = 3) -> [ExerciseHistoryEntry] {
        let result = matchingService.findBestMatch(for: exerciseName)
        guard let exercise = result.exercise, result.confidence >= matchingService.fuzzyMatchThreshold else { return [] }
        
        // Get workout exercises sorted by date (newest first)
        let workoutExercises = exercise.history
            .filter { $0.session != nil && !$0.sets.isEmpty }
            .sorted { ($0.session?.startTime ?? .distantPast) > ($1.session?.startTime ?? .distantPast) }
            .prefix(limit)
        
        return workoutExercises.map { workoutExercise in
            let orderedSets = workoutExercise.orderedSets
            let maxWeight = orderedSets.map(\.weight).max() ?? 0
            let bestRepsAtMax = orderedSets.filter { $0.weight == maxWeight }.map(\.reps).max() ?? 0
            
            return ExerciseHistoryEntry(
                date: workoutExercise.session?.startTime ?? Date(),
                sets: orderedSets.map { ExerciseHistoryEntry.SetEntry(weight: $0.weight, reps: $0.reps) },
                maxWeight: maxWeight,
                bestRepsAtMaxWeight: bestRepsAtMax
            )
        }
    }
    
    /// Get workout history for a specific muscle group
    func getHistory(forMuscleGroup muscleGroup: String, limit: Int = 5) -> [WorkoutSession] {
        let normalized = muscleGroup.lowercased()
        
        // Fetch all sessions and filter by muscle group
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        guard let sessions = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        // Filter sessions that contain exercises for this muscle group
        let filtered = sessions.filter { session in
            session.exercises.contains { workoutExercise in
                workoutExercise.exercise?.muscleGroup.lowercased().contains(normalized) ?? false
            } || session.label.lowercased().contains(normalized)
        }
        
        return Array(filtered.prefix(limit))
    }
    
    /// Search sessions by label
    func searchSessions(query: String) -> [WorkoutSession] {
        let normalized = query.lowercased()
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.label.localizedStandardContains(normalized)
            },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Summary Generation
    
    /// Generate a text summary of recent workout history
    func generateHistorySummary(limit: Int = 3) -> String {
        let sessions = getRecentSessions(limit: limit)
        
        if sessions.isEmpty {
            return "No workout history yet. Let's get started!"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"  // Day name
        
        var summaries: [String] = []
        for session in sessions {
            let day = formatter.string(from: session.startTime)
            summaries.append("\(day): \(session.label)")
        }
        
        return summaries.joined(separator: ", ")
    }
    
    /// Generate summary for a specific exercise
    func generateExerciseSummary(exerciseName: String) -> String? {
        guard let lastPerformed = getLastExerciseStats(exerciseName: exerciseName) else {
            return nil
        }
        
        guard let session = lastPerformed.session else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let date = formatter.string(from: session.startTime)
        let sets = lastPerformed.orderedSets
        
        if let topSet = sets.max(by: { $0.weight < $1.weight }) {
            return "Last time (\(date)): \(topSet.quickSummary)"
        }
        
        return "Last performed: \(date)"
    }
    
    // MARK: - Edit & Delete Operations
    
    /// Edit a logged set
    func editSet(
        exerciseName: String,
        setIdentifier: String,
        newWeight: Double?,
        newReps: Int?
    ) -> EditSetResult? {
        guard let session = getActiveSession() else { return nil }
        
        // Find the exercise
        let result = matchingService.findBestMatch(for: exerciseName)
        guard let exercise = result.exercise, result.confidence >= matchingService.fuzzyMatchThreshold else { return nil }
        
        guard let workoutExercise = session.exercises.first(where: { $0.exercise?.id == exercise.id }) else {
            return nil
        }
        
        let orderedSets = workoutExercise.orderedSets
        guard !orderedSets.isEmpty else { return nil }
        
        // Find the target set
        let targetSet: WorkoutSet?
        let identifier = setIdentifier.lowercased()
        
        if identifier == "last" {
            targetSet = orderedSets.last
        } else if identifier == "first" {
            targetSet = orderedSets.first
        } else if let setNum = Int(identifier), setNum > 0 && setNum <= orderedSets.count {
            targetSet = orderedSets[setNum - 1]
        } else {
            targetSet = orderedSets.last
        }
        
        guard let set = targetSet else { return nil }
        
        // Apply changes
        if let weight = newWeight {
            set.weight = weight
        }
        if let reps = newReps {
            set.reps = reps
        }
        
        try? modelContext.save()
        
        return EditSetResult(
            exerciseName: exercise.name,
            setNumber: set.setNumber,
            weight: set.weight,
            reps: set.reps
        )
    }
    
    /// Delete a logged set
    func deleteSet(
        exerciseName: String,
        setIdentifier: String
    ) -> DeleteSetResult? {
        guard let session = getActiveSession() else { return nil }
        
        // Find the exercise
        let result = matchingService.findBestMatch(for: exerciseName)
        guard let exercise = result.exercise, result.confidence >= matchingService.fuzzyMatchThreshold else { return nil }
        
        guard let workoutExercise = session.exercises.first(where: { $0.exercise?.id == exercise.id }) else {
            return nil
        }
        
        let orderedSets = workoutExercise.orderedSets
        guard !orderedSets.isEmpty else { return nil }
        
        // Find the target set
        let targetSet: WorkoutSet?
        let identifier = setIdentifier.lowercased()
        
        if identifier == "last" {
            targetSet = orderedSets.last
        } else if identifier == "first" {
            targetSet = orderedSets.first
        } else if let setNum = Int(identifier), setNum > 0 && setNum <= orderedSets.count {
            targetSet = orderedSets[setNum - 1]
        } else {
            targetSet = orderedSets.last
        }
        
        guard let set = targetSet else { return nil }
        
        let setNumber = set.setNumber
        let exerciseNameResult = exercise.name
        
        // Remove the set
        workoutExercise.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        
        // Renumber remaining sets
        for (index, remainingSet) in workoutExercise.orderedSets.enumerated() {
            remainingSet.setNumber = index + 1
        }
        
        try? modelContext.save()
        
        return DeleteSetResult(
            exerciseName: exerciseNameResult,
            setNumber: setNumber
        )
    }
    
    /// Delete an entire exercise from the current workout
    func deleteExercise(exerciseName: String) -> Bool {
        guard let session = getActiveSession() else { return false }
        
        // Find the exercise
        let result = matchingService.findBestMatch(for: exerciseName)
        guard let exercise = result.exercise, result.confidence >= matchingService.fuzzyMatchThreshold else { return false }
        
        guard let workoutExercise = session.exercises.first(where: { $0.exercise?.id == exercise.id }) else {
            return false
        }
        
        // Delete all sets first
        for set in workoutExercise.sets {
            modelContext.delete(set)
        }
        
        // Remove from session
        session.exercises.removeAll { $0.id == workoutExercise.id }
        
        // Delete the workout exercise
        modelContext.delete(workoutExercise)
        
        try? modelContext.save()
        
        return true
    }
    
    /// Update an exercise from the edit sheet
    /// - Parameters:
    ///   - exerciseName: Current exercise name to find
    ///   - newExerciseName: New exercise name (may be same or different)
    ///   - updatedSets: Array of updated (weight, reps) for each set
    /// - Returns: true if successful
    func updateExerciseFromEdit(
        exerciseName: String,
        newExerciseName: String,
        updatedSets: [(weight: Double, reps: Int)]
    ) -> Bool {
        guard let session = getActiveSession() else { return false }
        
        // Find the workout exercise by current name
        let result = matchingService.findBestMatch(for: exerciseName)
        guard let exercise = result.exercise, result.confidence >= matchingService.fuzzyMatchThreshold else { return false }
        
        guard let workoutExercise = session.exercises.first(where: { $0.exercise?.id == exercise.id }) else {
            return false
        }
        
        // If exercise name changed, update to new exercise
        if exerciseName.lowercased() != newExerciseName.lowercased() {
            let newExercise = matchingService.findOrCreate(
                name: newExerciseName, 
                muscleGroup: exercise.muscleGroup
            )
            
            // Update the workout exercise to point to the new exercise
            workoutExercise.exercise = newExercise
            newExercise.history.append(workoutExercise)
        }
        
        // Update sets
        // Update sets
        let orderedSets = workoutExercise.orderedSets
        
        // 1. Update existing sets
        for (index, setData) in updatedSets.enumerated() {
            if index < orderedSets.count {
                orderedSets[index].weight = setData.weight
                orderedSets[index].reps = setData.reps
            } else {
                // Handle potentially added sets (robustness)
                let newSet = WorkoutSet(
                    setNumber: index + 1,
                    weight: setData.weight,
                    reps: setData.reps,
                    isPR: false, // Re-evaluating PRs would be complex here, keeping simple
                    workoutExercise: workoutExercise
                )
                modelContext.insert(newSet)
                workoutExercise.sets.append(newSet)
            }
        }
        
        // 2. Delete extra sets if any were removed
        if orderedSets.count > updatedSets.count {
            // Get the sets that need to be removed (from the end)
            // Note: orderedSets are sorted by setNumber, so we remove the highest numbers
            let setsToRemove = orderedSets.suffix(orderedSets.count - updatedSets.count)
            
            for set in setsToRemove {
                // Delete from context
                modelContext.delete(set)
                
                // Remove from the relationship array
                if let idx = workoutExercise.sets.firstIndex(where: { $0.id == set.id }) {
                    workoutExercise.sets.remove(at: idx)
                }
            }
        }
        
        try? modelContext.save()
        return true
    }
}

