//
//  ChatMessage.swift
//  Spot
//
//  Represents a single message in the chat conversation.
//  Persisted to maintain context between sessions.
//

import Foundation
import SwiftData

/// The sender of a chat message
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

@Model
final class ChatMessage {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// The message content
    var content: String
    
    /// Who sent this message (user, assistant, or system)
    var roleRawValue: String
    
    /// When the message was sent
    var timestamp: Date
    
    /// Whether this message is currently being streamed (for typing animation)
    var isStreaming: Bool
    
    /// Optional reference to a workout session this message relates to
    var relatedSessionID: UUID?
    
    /// Logged exercise data (for set logging confirmations)
    /// Stored as JSON string for SwiftData compatibility
    var loggedExerciseDataJSON: String?
    
    // MARK: - Relationships
    
    /// The conversation this message belongs to
    var conversation: Conversation?
    
    // MARK: - Initialization
    
    init(
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        relatedSessionID: UUID? = nil,
        conversation: Conversation? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.roleRawValue = role.rawValue
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.relatedSessionID = relatedSessionID
        self.conversation = conversation
    }
    
    // MARK: - Computed Properties
    
    /// The role as an enum (computed from stored raw value)
    var role: MessageRole {
        get {
            MessageRole(rawValue: roleRawValue) ?? .user
        }
        set {
            roleRawValue = newValue.rawValue
        }
    }
    
    /// Whether this message is from the user
    var isUser: Bool {
        role == .user
    }
    
    /// Whether this message is from the AI assistant
    var isAssistant: Bool {
        role == .assistant
    }
    
    /// Formatted timestamp for display (e.g., "2:34 PM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Decoded logged exercise info (computed from JSON)
    var loggedExerciseInfo: LoggedExerciseInfo? {
        get {
            guard let json = loggedExerciseDataJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(LoggedExerciseInfo.self, from: data)
        }
        set {
            if let info = newValue,
               let data = try? JSONEncoder().encode(info),
               let json = String(data: data, encoding: .utf8) {
                loggedExerciseDataJSON = json
            } else {
                loggedExerciseDataJSON = nil
            }
        }
    }
    
    /// Whether this message contains a logged exercise
    var hasLoggedExercise: Bool {
        loggedExerciseInfo != nil
    }
}

// MARK: - Convenience Initializers

extension ChatMessage {
    /// Create a user message
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(content: content, role: .user)
    }
    
    /// Create an assistant message
    static func assistant(_ content: String, isStreaming: Bool = false) -> ChatMessage {
        ChatMessage(content: content, role: .assistant, isStreaming: isStreaming)
    }
    
    /// Create a system message
    static func system(_ content: String) -> ChatMessage {
        ChatMessage(content: content, role: .system)
    }
}

