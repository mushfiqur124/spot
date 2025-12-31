//
//  LLMService.swift
//  Spot
//
//  Service for interacting with Apple's Foundation Model.
//  Handles response generation using on-device LLM with custom tools.
//

import Foundation
import SwiftData
import FoundationModels

/// Errors that can occur during LLM operations
enum LLMError: Error, LocalizedError {
    case notAvailable
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case generationFailed(String)
    case toolExecutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Foundation Models not available"
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled on this device"
        case .modelNotReady:
            return "The AI model is still downloading. Please try again later."
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        }
    }
}

/// Availability status for Foundation Models
enum FoundationModelsAvailability {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown
}

@available(iOS 26.0, *)
@MainActor
class LLMService {
    private let modelContext: ModelContext
    private let workoutService: WorkoutService
    private var session: LanguageModelSession
    private let model = SystemLanguageModel.default
    
    // MARK: - Static Availability Check
    
    /// Check if Foundation Models is available on this device
    static func checkAvailability() -> FoundationModelsAvailability {
        let model = SystemLanguageModel.default
        
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, workoutService: WorkoutService) throws {
        self.modelContext = modelContext
        self.workoutService = workoutService
        
        // Check availability
        switch model.availability {
        case .available:
            break // Continue initialization
        case .unavailable(.deviceNotEligible):
            throw LLMError.deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            throw LLMError.appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            throw LLMError.modelNotReady
        case .unavailable:
            throw LLMError.notAvailable
        @unknown default:
            throw LLMError.notAvailable
        }
        
        // Create tool instances
        let tools: [any Tool] = [
            LogSessionTool(workoutService: workoutService),
            LogSetTool(workoutService: workoutService),
            EditSetTool(workoutService: workoutService),
            DeleteSetTool(workoutService: workoutService),
            GetRecentHistoryTool(workoutService: workoutService),
            GetLastExerciseStatsTool(workoutService: workoutService),
            GetPersonalRecordTool(workoutService: workoutService),
            GetAllPersonalRecordsTool(workoutService: workoutService),
            CalculatePlateMathTool()
        ]
        
        // Create session with tools and instructions
        self.session = LanguageModelSession(
            tools: tools,
            instructions: SystemPrompt.full
        )
    }
    
    // MARK: - Response Generation
    
    func generateResponse(
        userMessage: String,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        do {
            let response = try await session.respond(to: userMessage)
            return response.content
        } catch {
            throw LLMError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Streaming Response
    
    func streamResponse(
        userMessage: String,
        conversationHistory: [ChatMessage],
        onPartial: @escaping (String) -> Void
    ) async throws -> String {
        var fullResponse = ""
        
        do {
            let stream = session.streamResponse(to: userMessage)
            
            for try await partial in stream {
                fullResponse = partial.content
                onPartial(partial.content)
            }
            
            return fullResponse
        } catch {
            throw LLMError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Pre-warm Model
    
    func prewarm() {
        session.prewarm()
    }
}
