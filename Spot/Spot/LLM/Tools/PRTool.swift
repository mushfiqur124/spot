//
//  PRTool.swift
//  Spot
//
//  Tool for retrieving personal records.
//  Conforms to Foundation Models Tool protocol.
//

import Foundation
import FoundationModels

/// Tool for retrieving personal records
@available(iOS 26.0, *)
struct GetPersonalRecordTool: Tool {
    // Required metadata
    var name: String = "get_personal_record"
    var description: String = "Gets the user's all-time personal record (PR) for a specific exercise. Use when the user asks about their PR, best lift, or max weight for an exercise."
    
    // Required output type
    typealias Output = String
    
    // Arguments the AI extracts from user input
    @Generable
    struct Arguments {
        @Guide(description: "The name of the exercise to get the PR for (e.g., 'Bench Press', 'Squat', 'Deadlift')")
        var exerciseName: String
    }
    
    let workoutService: WorkoutService
    
    // The logic that runs when AI calls this tool
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        guard let pr = workoutService.getPR(exerciseName: arguments.exerciseName) else {
            return "No PR recorded for \(arguments.exerciseName) yet. Time to set one!"
        }
        
        var response = "PR for \(arguments.exerciseName): \(Int(pr.weight)) lbs"
        
        if pr.volume > 0 {
            response += " (Best volume: \(Int(pr.volume)) lbs total)"
        }
        
        return response
    }
}
