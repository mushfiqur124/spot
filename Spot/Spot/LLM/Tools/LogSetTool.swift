//
//  LogSetTool.swift
//  Spot
//
//  Tool for logging sets of exercises.
//  Supports multiple sets and multiple exercises in one call.
//  Conforms to Foundation Models Tool protocol.
//

import Foundation
import FoundationModels

/// Tool for logging multiple sets of an exercise
@available(iOS 26.0, *)
struct LogSetTool: Tool {
    // Required metadata
    var name: String = "log_sets"
    var description: String = "Records one or more sets for an exercise. Use when user tells you about sets they did, like 'bench 185 for 8', '3 sets of squats 225x5', or 'did 4 sets of 10 at 135'. Can log multiple sets at once if they're the same weight/reps. For different exercises, call this tool multiple times."
    
    // Required output type
    typealias Output = String
    
    // Arguments the AI extracts from user input
    @Generable
    struct Arguments {
        @Guide(description: "The exercise name (e.g., 'Bench Press', 'Squat', 'Deadlift', 'Pull-ups', 'Dips')")
        var exerciseName: String
        
        @Guide(description: "The weight lifted in pounds. Use 0 for bodyweight exercises like pull-ups, dips, push-ups. If user adds weight to bodyweight exercise (e.g., 'weighted dips +25 lbs'), use that added weight.")
        var weightLbs: Double?
        
        @Guide(description: "Number of repetitions completed per set")
        var reps: Int
        
        @Guide(description: "Number of sets to log (default 1). Use when user says '3 sets' or 'did 4 sets'")
        var numberOfSets: Int?
        
        @Guide(description: "Rate of Perceived Exertion from 1-10, if the user mentioned how hard it felt")
        var rpe: Int?
        
        @Guide(description: "True if this is a bodyweight exercise with no added weight (pull-ups, dips, push-ups, sit-ups, etc.)")
        var isBodyweight: Bool?
    }
    
    let workoutService: WorkoutService
    
    // Common bodyweight exercises that don't require weight input
    private static let bodyweightExercises = [
        "pull-up", "pullup", "pull up", "chin-up", "chinup", "chin up",
        "dip", "dips", "push-up", "pushup", "push up",
        "sit-up", "situp", "sit up", "crunch", "crunches",
        "plank", "lunge", "lunges", "squat jump", "burpee", "burpees",
        "mountain climber", "leg raise", "hanging leg raise"
    ]
    
    // The logic that runs when AI calls this tool
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let muscleGroup = guessMuscleGroup(for: arguments.exerciseName)
        let setsToLog = max(1, arguments.numberOfSets ?? 1)
        
        // Determine if this is a bodyweight exercise
        let exerciseLower = arguments.exerciseName.lowercased()
        let isCommonBodyweight = Self.bodyweightExercises.contains { exerciseLower.contains($0) }
        let isBodyweight = arguments.isBodyweight ?? isCommonBodyweight
        
        // Determine weight: 0 for bodyweight, otherwise use provided weight
        let weight: Double
        if isBodyweight && (arguments.weightLbs == nil || arguments.weightLbs == 0) {
            weight = 0
        } else {
            weight = arguments.weightLbs ?? 0
        }
        
        var results: [LogSetResult] = []
        var hadPR = false
        var previousBest: Double?
        
        // Log each set
        for _ in 0..<setsToLog {
            guard let result = workoutService.logSet(
                exerciseName: arguments.exerciseName,
                weight: weight,
                reps: arguments.reps,
                rpe: arguments.rpe,
                muscleGroup: muscleGroup,
                isBodyweight: isBodyweight
            ) else {
                return "No active workout session. Start one first by telling me what you're training today!"
            }
            
            results.append(result)
            if result.isPR {
                hadPR = true
                previousBest = result.previousBest
            }
        }
        
        guard let firstResult = results.first else {
            return "Failed to log sets."
        }
        
        // Build response
        let weightDisplay = isBodyweight && weight == 0 ? "BW" : "\(Int(weight)) lbs"
        var response = "Logged: \(firstResult.exercise.name) - \(setsToLog) set\(setsToLog == 1 ? "" : "s") of \(weightDisplay) x \(arguments.reps)"
        
        if hadPR && !isBodyweight {
            response += " - NEW PR!"
            if let previous = previousBest {
                response += " (Previous best: \(Int(previous)) lbs)"
            }
        } else if hadPR && isBodyweight {
            response += " - NEW REP PR!"
        }
        
        return response
    }
    
    private func guessMuscleGroup(for exercise: String) -> String {
        let lowercased = exercise.lowercased()
        
        if lowercased.contains("bench") || lowercased.contains("chest") || lowercased.contains("fly") || lowercased.contains("push") {
            return "Chest"
        }
        if lowercased.contains("squat") || lowercased.contains("leg") || lowercased.contains("lunge") || lowercased.contains("calf") || lowercased.contains("glute") || lowercased.contains("ham") {
            return "Legs"
        }
        if lowercased.contains("deadlift") || lowercased.contains("row") || lowercased.contains("pull") || lowercased.contains("lat") || lowercased.contains("back") {
            return "Back"
        }
        if lowercased.contains("shoulder") || lowercased.contains("delt") || lowercased.contains("ohp") || lowercased.contains("military") {
            return "Shoulders"
        }
        if lowercased.contains("curl") || lowercased.contains("bicep") || lowercased.contains("tricep") || lowercased.contains("arm") || lowercased.contains("extension") {
            return "Arms"
        }
        if lowercased.contains("press") && !lowercased.contains("leg") {
            return "Chest"
        }
        
        return "Other"
    }
}
