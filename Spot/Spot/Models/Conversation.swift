//
//  Conversation.swift
//  Spot
//
//  Represents a chat conversation - can be either a workout session
//  or a general informational chat.
//

import Foundation
import SwiftData

/// The type of conversation
enum ConversationType: String, Codable {
    case general    // Informational chats (PRs, exercise info, advice)
    case workout    // Active workout logging session
}

@Model
final class Conversation {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// Display title for the conversation
    /// - Workout: From session label ("Push Day")
    /// - General: Auto-generated from content ("Bench Press PR")
    var title: String
    
    /// The type of conversation
    var typeRawValue: String
    
    /// When the conversation was created
    var createdAt: Date
    
    /// When the last message was sent
    var lastMessageAt: Date
    
    /// Whether this conversation is currently active
    var isActive: Bool
    
    // MARK: - Relationships
    
    /// Messages in this conversation (cascade delete)
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []
    
    /// Linked workout session (only for workout type)
    var linkedSession: WorkoutSession?
    
    // MARK: - Initialization
    
    init(
        title: String = "New Chat",
        type: ConversationType = .general,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.typeRawValue = type.rawValue
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.isActive = isActive
    }
    
    // MARK: - Computed Properties
    
    /// The conversation type as an enum
    var type: ConversationType {
        get {
            ConversationType(rawValue: typeRawValue) ?? .general
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }
    
    /// Whether this is a workout conversation
    var isWorkout: Bool {
        type == .workout
    }
    
    /// Messages sorted by timestamp
    var orderedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// The first user message (for auto-titling)
    var firstUserMessage: String? {
        orderedMessages.first { $0.role == .user }?.content
    }
    
    /// Summary subtitle for display
    var subtitle: String {
        if isWorkout, let session = linkedSession {
            let exerciseCount = session.exercises.count
            if exerciseCount > 0 {
                return "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"
            }
            return "No exercises yet"
        } else {
            return relativeTimeString
        }
    }
    
    /// Relative time string for last message
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastMessageAt, relativeTo: Date())
    }
    
    // MARK: - Methods
    
    /// Convert this conversation to a workout type
    func convertToWorkout(session: WorkoutSession) {
        self.type = .workout
        self.title = session.label
        self.linkedSession = session
    }
    
    /// Update the last message timestamp
    func touchLastMessage() {
        self.lastMessageAt = Date()
    }
}

// MARK: - Auto Title Generation

extension Conversation {
    /// Keywords for auto-generating titles
    private static let topicKeywords: [(keywords: [String], title: String)] = [
        (["pr", "personal record", "max", "best"], "PR Questions"),
        (["form", "technique", "how to", "proper"], "Form & Technique"),
        (["shoulder", "delt"], "Shoulder Info"),
        (["chest", "pec", "bench"], "Chest Info"),
        (["back", "lat", "row"], "Back Info"),
        (["leg", "squat", "quad", "hamstring"], "Leg Info"),
        (["arm", "bicep", "tricep", "curl"], "Arm Info"),
        (["core", "ab", "abs"], "Core Info"),
        (["cardio", "run", "hiit"], "Cardio Info"),
        (["program", "routine", "split", "schedule"], "Training Program"),
        (["diet", "nutrition", "protein", "calories"], "Nutrition"),
        (["rest", "recovery", "sleep"], "Recovery"),
        (["warm up", "stretch"], "Warm Up & Mobility"),
    ]
    
    /// Generate a title based on message content
    static func generateTitle(from message: String) -> String {
        let lowercased = message.lowercased()
        
        // Check for topic keywords
        for (keywords, title) in topicKeywords {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return title
            }
        }
        
        // Fallback: Use first few words
        let words = message.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: " ")
        
        if words.count > 30 {
            return String(words.prefix(30)) + "..."
        }
        
        return words.isEmpty ? "New Chat" : words
    }
    
    /// Update title based on first user message (for general chats)
    func autoGenerateTitle() {
        guard type == .general, let firstMessage = firstUserMessage else { return }
        self.title = Conversation.generateTitle(from: firstMessage)
    }
}

