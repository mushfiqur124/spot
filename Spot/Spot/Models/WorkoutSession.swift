//
//  WorkoutSession.swift
//  Spot
//
//  Represents a single trip to the gym.
//  Contains all exercises performed during that session.
//

import Foundation
import SwiftData

@Model
final class WorkoutSession {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// When the workout started
    var startTime: Date
    
    /// When the workout finished (nil if still in progress)
    var endTime: Date?
    
    /// User-friendly label (e.g., "Push Day", "Leg Day", "Morning Cardio")
    var label: String
    
    /// AI-generated summary of the workout
    var summary: String?
    
    // MARK: - Relationships
    
    /// The exercises performed in this session (cascade delete - if session is deleted, exercises go too)
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise] = []
    
    // MARK: - Initialization
    
    init(
        label: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        summary: String? = nil
    ) {
        self.id = UUID()
        self.label = label
        self.startTime = startTime
        self.endTime = endTime
        self.summary = summary
    }
    
    // MARK: - Computed Properties
    
    /// Whether the workout is still in progress
    var isActive: Bool {
        endTime == nil
    }
    
    /// Duration of the workout in seconds
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Formatted duration string (e.g., "1h 23m")
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Total volume across all exercises in this session
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }
    
    /// Total number of sets in this session
    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    /// All unique muscle groups worked in this session
    var muscleGroups: [String] {
        let groups = exercises.compactMap { $0.exercise?.muscleGroup }
        return Array(Set(groups)).sorted()
    }
    
    /// Exercises sorted by their order in the workout
    var orderedExercises: [WorkoutExercise] {
        exercises.sorted { $0.orderIndex < $1.orderIndex }
    }
}

