//
//  HistoryTool.swift
//  Spot
//
//  Tool for retrieving recent workout history.
//  Conforms to Foundation Models Tool protocol.
//

import Foundation
import FoundationModels

/// Tool for fetching recent workout history
@available(iOS 26.0, *)
struct GetRecentHistoryTool: Tool {
    // Required metadata
    var name: String = "get_recent_history"
    var description: String = "Fetches the user's recent workout sessions. Use when the user asks about their workout history, what they did recently, or wants to see past sessions. Returns a summary of recent workouts with dates and exercises."
    
    // Required output type
    typealias Output = String
    
    // Arguments the AI extracts from user input
    @Generable
    struct Arguments {
        @Guide(description: "Number of past sessions to retrieve (default is 3, max is 10)")
        var limit: Int?
    }
    
    let workoutService: WorkoutService
    
    // The logic that runs when AI calls this tool
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let limit = min(arguments.limit ?? 3, 10)
        let sessions = workoutService.getRecentSessions(limit: limit)
        
        if sessions.isEmpty {
            return "No workout history found. This is a fresh start!"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Day name
        
        var summaries: [String] = []
        
        for session in sessions {
            let day = formatter.string(from: session.startTime)
            let exerciseCount = session.exercises.count
            let setCount = session.totalSets
            
            var summary = "\(day): \(session.label)"
            if exerciseCount > 0 {
                summary += " (\(exerciseCount) exercises, \(setCount) sets)"
                
                // Add exercise names (access through the exercise relationship)
                let exerciseNames = session.exercises.prefix(3).compactMap { $0.exercise?.name }
                if !exerciseNames.isEmpty {
                    summary += " - \(exerciseNames.joined(separator: ", "))"
                    if session.exercises.count > 3 {
                        summary += "..."
                    }
                }
            }
            summaries.append(summary)
        }
        
        return "Recent workouts: " + summaries.joined(separator: "; ")
    }
}
