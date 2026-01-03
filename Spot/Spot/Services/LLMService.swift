//
//  LLMService.swift
//  Spot
//
//  Manager for AI services.
//  Uses Gemini as the primary and only AI backend.
//

import Foundation
import SwiftData

/// Errors that can occur during LLM operations
enum LLMError: Error, LocalizedError {
    case notAvailable
    case generationFailed(String)
    case toolExecutionFailed(String)
    case geminiNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "AI service not available"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        case .geminiNotConfigured:
            return "Gemini API key not configured. Please add your key to Secrets.swift"
        }
    }
}

@available(iOS 26.0, *)
@MainActor
class LLMService {
    private let modelContext: ModelContext
    private let workoutService: WorkoutService
    private var currentService: (any AIService)?
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, workoutService: WorkoutService) throws {
        self.modelContext = modelContext
        self.workoutService = workoutService
        
        // Initialize Gemini service
        do {
            self.currentService = try GeminiService(workoutService: workoutService)
            print("Initialized with Gemini AI")
        } catch {
            print("Failed to initialize Gemini service: \(error)")
            throw LLMError.geminiNotConfigured
        }
    }
    
    // MARK: - Response Generation
    
    func generateResponse(
        userMessage: String,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        guard let service = currentService else {
            throw LLMError.notAvailable
        }
        
        var fullResponse = ""
        let stream = try await service.sendMessage(userMessage, history: conversationHistory)
        
        for try await partial in stream {
            fullResponse = partial
        }
        
        return fullResponse
    }
    
    // MARK: - Streaming Response
    
    func streamResponse(
        userMessage: String,
        conversationHistory: [ChatMessage],
        onPartial: @escaping (String) -> Void
    ) async throws -> String {
        guard let service = currentService else {
            throw LLMError.notAvailable
        }
        
        var fullResponse = ""
        let stream = try await service.sendMessage(userMessage, history: conversationHistory)
        
        for try await partial in stream {
            fullResponse = partial
            onPartial(partial)
        }
        
        return fullResponse
    }
    
    // MARK: - Pre-warm Model
    
    func prewarm() {
        currentService?.prewarm()
    }
    
    // MARK: - Session Management
    
    /// Reset the LLM session to clear context history.
    /// Call this when switching to a different conversation to prevent context mixing.
    func resetSession() {
        currentService?.resetSession()
    }
}
