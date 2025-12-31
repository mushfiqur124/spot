//
//  LogSessionTool.swift
//  Spot
//
//  Tool for starting a new workout session.
//  Conforms to Foundation Models Tool protocol.
//

import Foundation
import FoundationModels

/// Tool for starting a new workout session
@available(iOS 26.0, *)
struct LogSessionTool: Tool {
    // Required metadata
    var name: String = "log_workout_session"
    var description: String = "Starts a new workout session with a focus area. Use when the user says they're starting a workout, mentions what body part they're training (like 'chest day', 'leg day', 'push day'), or wants to begin logging exercises."
    
    // Required output type
    typealias Output = String
    
    // Arguments the AI extracts from user input
    @Generable
    struct Arguments {
        @Guide(description: "The focus of the workout session (e.g., 'Push Day', 'Pull Day', 'Leg Day', 'Upper Body', 'Chest', 'Back')")
        var focusArea: String
    }
    
    let workoutService: WorkoutService
    
    // The logic that runs when AI calls this tool
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        _ = workoutService.startSession(label: arguments.focusArea)
        return "Started \(arguments.focusArea) session. Ready to log exercises!"
    }
}
