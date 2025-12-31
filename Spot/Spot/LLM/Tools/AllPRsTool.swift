//
//  AllPRsTool.swift
//  Spot
//
//  Tool for retrieving all personal records across exercises.
//  Returns multiple PRs at once for displaying to the user.
//

import Foundation
import FoundationModels

/// Tool for retrieving all personal records
@available(iOS 26.0, *)
struct GetAllPersonalRecordsTool: Tool {
    // Required metadata
    var name: String = "get_all_personal_records"
    var description: String = "Gets all of the user's personal records (PRs) across all exercises. Use when user asks about their PRs in general, like 'what are my PRs?', 'show me my records', or 'list my best lifts'. Returns up to 5 PRs by default, with info about how many more exist."
    
    // Required output type
    typealias Output = String
    
    // Arguments the AI extracts from user input
    @Generable
    struct Arguments {
        @Guide(description: "Maximum number of PRs to return (default 5, max 20)")
        var limit: Int?
        
        @Guide(description: "Optional filter by muscle group (e.g., 'Chest', 'Back', 'Legs')")
        var muscleGroup: String?
    }
    
    let workoutService: WorkoutService
    
    // The logic that runs when AI calls this tool
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let requestedLimit = min(arguments.limit ?? 5, 20)
        let result = workoutService.getAllPRs(limit: requestedLimit, muscleGroup: arguments.muscleGroup)
        
        if result.prs.isEmpty {
            if let muscleGroup = arguments.muscleGroup {
                return "No PRs recorded for \(muscleGroup) exercises yet. Time to set some!"
            }
            return "No PRs recorded yet. Let's get some lifts in and set your first records!"
        }
        
        var response = "Personal Records:\n"
        for pr in result.prs {
            response += "• \(pr.exerciseName): \(Int(pr.weight)) lbs"
            if pr.volume > 0 {
                response += " (Volume PR: \(Int(pr.volume)) lbs)"
            }
            response += "\n"
        }
        
        if result.totalCount > result.prs.count {
            let remaining = result.totalCount - result.prs.count
            response += "\nYou have PRs for \(remaining) more exercise\(remaining == 1 ? "" : "s")."
        }
        
        return response
    }
}

/// Result structure for getAllPRs
struct AllPRsResult {
    struct PREntry {
        let exerciseName: String
        let weight: Double
        let volume: Double
        let muscleGroup: String
    }
    
    let prs: [PREntry]
    let totalCount: Int
}

