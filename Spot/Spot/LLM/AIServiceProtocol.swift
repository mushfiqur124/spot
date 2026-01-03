//
//  AIServiceProtocol.swift
//  Spot
//
//  Protocol defining the AI service interface for the Strategy Pattern.
//  Both LocalLLMService and GeminiService conform to this protocol.
//

import Foundation

/// Protocol for AI services that can generate responses to user messages
@available(iOS 26.0, *)
@MainActor
protocol AIService {
    /// Send a message and receive a streaming response
    /// - Parameters:
    ///   - text: The user's message
    ///   - history: Previous messages in the conversation
    /// - Returns: An async stream of partial response strings
    func sendMessage(_ text: String, history: [ChatMessage]) async throws -> AsyncThrowingStream<String, Error>
    
    /// Reset the conversation context
    func resetSession()
    
    /// Pre-warm the model for faster first response (optional)
    func prewarm()
}

/// Default implementations for optional methods
@available(iOS 26.0, *)
extension AIService {
    func prewarm() {
        // Default no-op implementation
    }
}
