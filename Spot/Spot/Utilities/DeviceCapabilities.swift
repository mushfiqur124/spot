//
//  DeviceCapabilities.swift
//  Spot
//
//  Utility for checking device capabilities and Apple Intelligence availability.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum DeviceCapabilities {
    
    #if canImport(FoundationModels)
    private static let model = SystemLanguageModel.default
    #endif
    
    /// Check if Apple Intelligence / Foundation Models are available
    static var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = model.availability {
            return true
        }
        return false
        #else
        return false
        #endif
    }
    
    /// Human-readable status message
    static var intelligenceStatusMessage: String {
        #if canImport(FoundationModels)
        switch model.availability {
        case .available:
            return "Apple Intelligence is ready"
        case .unavailable(.deviceNotEligible):
            return "Apple Intelligence is not available on this device"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is not enabled in Settings"
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is not ready yet"
        case .unavailable:
            return "Apple Intelligence is not available"
        @unknown default:
            return "Apple Intelligence status unknown"
        }
        #else
        return "This iOS version doesn't support Apple Intelligence"
        #endif
    }
    
    /// Check iOS version
    static var iOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    /// Check if running on simulator
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

