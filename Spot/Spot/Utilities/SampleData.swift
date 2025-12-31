//
//  SampleData.swift
//  Spot
//
//  Sample data for SwiftUI previews and testing.
//

import Foundation
import SwiftData

@MainActor
enum SampleData {
    
    // MARK: - Sample Exercises
    
    static func createSampleExercises(in context: ModelContext) -> [Exercise] {
        let exercises = [
            Exercise(name: "Bench Press", muscleGroup: "Chest", allTimeMaxWeight: 185),
            Exercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", allTimeMaxWeight: 70),
            Exercise(name: "Squat", muscleGroup: "Legs", allTimeMaxWeight: 225),
            Exercise(name: "Deadlift", muscleGroup: "Back", allTimeMaxWeight: 275),
            Exercise(name: "Lat Pulldown", muscleGroup: "Back", allTimeMaxWeight: 140),
            Exercise(name: "Overhead Press", muscleGroup: "Shoulders", allTimeMaxWeight: 115),
            Exercise(name: "Barbell Curl", muscleGroup: "Arms", allTimeMaxWeight: 65)
        ]
        
        exercises.forEach { context.insert($0) }
        return exercises
    }
    
    // MARK: - Sample Sessions
    
    static func createSampleSession(
        label: String = "Push Day",
        daysAgo: Int = 0,
        in context: ModelContext
    ) -> WorkoutSession {
        let startTime = Calendar.current.date(
            byAdding: .day,
            value: -daysAgo,
            to: Date()
        ) ?? Date()
        
        let endTime = Calendar.current.date(
            byAdding: .hour,
            value: 1,
            to: startTime
        )
        
        let session = WorkoutSession(
            label: label,
            startTime: startTime,
            endTime: daysAgo == 0 ? nil : endTime
        )
        
        context.insert(session)
        return session
    }
    
    // MARK: - Sample Chat Messages
    
    static func createSampleMessages(in context: ModelContext) -> [ChatMessage] {
        let messages = [
            ChatMessage.assistant("Hey! Ready to get after it today? What are we hitting?"),
            ChatMessage.user("Push day"),
            ChatMessage.assistant("Let's go! You haven't hit chest in 3 days. Last push session you benched 175 for 6. Feeling strong today?"),
            ChatMessage.user("Yeah let's start with bench. 135 for 8"),
            ChatMessage.assistant("Logged: Bench Press 135 x 8. Good warm-up set. What's next?")
        ]
        
        messages.forEach { context.insert($0) }
        return messages
    }
    
    // MARK: - Full Sample Workout
    
    static func createFullSampleWorkout(in context: ModelContext) {
        // Create exercises
        let bench = Exercise(name: "Bench Press", muscleGroup: "Chest", allTimeMaxWeight: 185)
        let incline = Exercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", allTimeMaxWeight: 70)
        let flies = Exercise(name: "Cable Flies", muscleGroup: "Chest")
        
        context.insert(bench)
        context.insert(incline)
        context.insert(flies)
        
        // Create session from 2 days ago
        let session = WorkoutSession(
            label: "Push Day",
            startTime: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            endTime: Calendar.current.date(byAdding: .day, value: -2, to: Date())?.addingTimeInterval(3600)
        )
        context.insert(session)
        
        // Bench Press workout
        let benchWorkout = WorkoutExercise(orderIndex: 0, session: session, exercise: bench)
        context.insert(benchWorkout)
        session.exercises.append(benchWorkout)
        bench.history.append(benchWorkout)
        
        let benchSets = [
            WorkoutSet(setNumber: 1, weight: 135, reps: 10, workoutExercise: benchWorkout),
            WorkoutSet(setNumber: 2, weight: 155, reps: 8, workoutExercise: benchWorkout),
            WorkoutSet(setNumber: 3, weight: 175, reps: 6, workoutExercise: benchWorkout),
            WorkoutSet(setNumber: 4, weight: 185, reps: 4, isPR: true, workoutExercise: benchWorkout)
        ]
        benchSets.forEach { 
            context.insert($0)
            benchWorkout.sets.append($0)
        }
        
        // Incline workout
        let inclineWorkout = WorkoutExercise(orderIndex: 1, session: session, exercise: incline)
        context.insert(inclineWorkout)
        session.exercises.append(inclineWorkout)
        incline.history.append(inclineWorkout)
        
        let inclineSets = [
            WorkoutSet(setNumber: 1, weight: 50, reps: 12, workoutExercise: inclineWorkout),
            WorkoutSet(setNumber: 2, weight: 60, reps: 10, workoutExercise: inclineWorkout),
            WorkoutSet(setNumber: 3, weight: 70, reps: 8, workoutExercise: inclineWorkout)
        ]
        inclineSets.forEach {
            context.insert($0)
            inclineWorkout.sets.append($0)
        }
    }
    
    // MARK: - Preview Container
    
    static var previewContainer: ModelContainer {
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            ChatMessage.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Add sample data
            let context = container.mainContext
            createFullSampleWorkout(in: context)
            _ = createSampleMessages(in: context)
            
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}

