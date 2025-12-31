//
//  LastStatsTool.swift
//  Spot
//
//  Tool for retrieving exercise history across sessions.
//  Conforms to Foundation Models Tool protocol.
//

import Foundation
import FoundationModels

/// Tool for retrieving exercise history
@available(iOS 26.0, *)
struct GetLastExerciseStatsTool: Tool {
    // Required metadata
    var name: String = "get_exercise_history"
    var description: String = """
        Retrieves the user's history for a specific exercise across past sessions. 
        IMPORTANT: Use this tool PROACTIVELY whenever:
        - User says they're about to do an exercise (e.g., "I'm doing tricep extensions", "next is bench")
        - User asks what they did last time for an exercise
        - User wants to know what weight to use
        Returns the weight, reps, and dates from recent sessions so you can tell them what they did before.
        """
    
    // Required output type
    typealias Output = String
    
    // Arguments the AI extracts from user input
    @Generable
    struct Arguments {
        @Guide(description: "The name of the exercise to look up (e.g., 'Bench Press', 'Squat', 'Tricep Extensions')")
        var exerciseName: String
        
        @Guide(description: "How many past sessions to retrieve (default 3, max 5)")
        var sessionCount: Int?
    }
    
    let workoutService: WorkoutService
    
    // The logic that runs when AI calls this tool
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let limit = min(arguments.sessionCount ?? 3, 5)
        let history = workoutService.getExerciseHistory(exerciseName: arguments.exerciseName, limit: limit)
        
        if history.isEmpty {
            return "No history found for \(arguments.exerciseName). This will be their first time!"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        var summaries: [String] = []
        
        for entry in history {
            let date = formatter.string(from: entry.date)
            let setSummaries = entry.sets.map { "\(Int($0.weight))x\($0.reps)" }
            summaries.append("\(date): \(setSummaries.joined(separator: ", ")) (max \(Int(entry.maxWeight)) lbs)")
        }
        
        var response = "\(arguments.exerciseName) history:\n"
        response += summaries.joined(separator: "\n")
        
        if let mostRecent = history.first {
            response += "\n\nLast time: \(Int(mostRecent.maxWeight)) lbs for \(mostRecent.bestRepsAtMaxWeight) reps"
        }
        
        return response
    }
}
