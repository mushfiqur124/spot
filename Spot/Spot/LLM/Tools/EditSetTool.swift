//
//  EditSetTool.swift
//  Spot
//
//  Tool for editing or deleting sets and exercises.
//  Allows users to correct mistakes in their logged data.
//

import Foundation
import FoundationModels

/// Tool for editing a logged set
@available(iOS 26.0, *)
struct EditSetTool: Tool {
    var name: String = "edit_set"
    var description: String = "Edits a previously logged set. Use when user wants to change the weight, reps, or correct a mistake. E.g., 'change my last bench set to 185', 'that should have been 8 reps not 10', 'fix my squat to 225'."
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        @Guide(description: "The exercise name to edit")
        var exerciseName: String
        
        @Guide(description: "Which set to edit: 'last', 'first', or a number like 1, 2, 3")
        var setIdentifier: String?
        
        @Guide(description: "New weight in pounds (if changing weight)")
        var newWeight: Double?
        
        @Guide(description: "New rep count (if changing reps)")
        var newReps: Int?
    }
    
    let workoutService: WorkoutService
    
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        guard let result = workoutService.editSet(
            exerciseName: arguments.exerciseName,
            setIdentifier: arguments.setIdentifier ?? "last",
            newWeight: arguments.newWeight,
            newReps: arguments.newReps
        ) else {
            return "Couldn't find that set to edit. Make sure you have an active workout with that exercise logged."
        }
        
        return "Updated: \(result.exerciseName) set \(result.setNumber) to \(Int(result.weight)) x \(result.reps)"
    }
}

/// Tool for deleting a set or exercise
@available(iOS 26.0, *)
struct DeleteSetTool: Tool {
    var name: String = "delete_set"
    var description: String = "Deletes a logged set or entire exercise from the current workout. Use when user says 'remove that set', 'delete my last bench set', 'remove squats from this workout'."
    
    typealias Output = String
    
    @Generable
    struct Arguments {
        @Guide(description: "The exercise name")
        var exerciseName: String
        
        @Guide(description: "Which set to delete: 'last', 'first', 'all' (removes entire exercise), or a number")
        var setIdentifier: String?
    }
    
    let workoutService: WorkoutService
    
    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let identifier = arguments.setIdentifier ?? "last"
        
        if identifier.lowercased() == "all" {
            // Delete entire exercise
            guard workoutService.deleteExercise(exerciseName: arguments.exerciseName) else {
                return "Couldn't find \(arguments.exerciseName) in your current workout."
            }
            return "Removed \(arguments.exerciseName) from your workout."
        } else {
            // Delete specific set
            guard let result = workoutService.deleteSet(
                exerciseName: arguments.exerciseName,
                setIdentifier: identifier
            ) else {
                return "Couldn't find that set to delete. Make sure you have an active workout with that exercise logged."
            }
            return "Deleted set \(result.setNumber) from \(result.exerciseName)."
        }
    }
}

/// Result from edit operation
struct EditSetResult {
    let exerciseName: String
    let setNumber: Int
    let weight: Double
    let reps: Int
}

/// Result from delete operation
struct DeleteSetResult {
    let exerciseName: String
    let setNumber: Int
}

