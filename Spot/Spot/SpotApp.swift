//
//  SpotApp.swift
//  Spot
//
//  Main entry point for the Spot fitness tracking app.
//

import SwiftUI
import SwiftData

@main
struct SpotApp: App {
    var sharedModelContainer: ModelContainer = {
        // Register all SwiftData models
        let schema = Schema([
            Exercise.self,
            WorkoutSession.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            ChatMessage.self,
            UserProfile.self,
            Conversation.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
