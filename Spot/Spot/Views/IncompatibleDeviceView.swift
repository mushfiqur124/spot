//
//  IncompatibleDeviceView.swift
//  Spot
//
//  Displayed when the device doesn't support Apple Intelligence / Foundation Models.
//  Explains requirements and supported devices.
//

import SwiftUI

struct IncompatibleDeviceView: View {
    let reason: IncompatibilityReason
    
    enum IncompatibilityReason {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case unknown
        
        var title: String {
            switch self {
            case .deviceNotEligible:
                return "Device Not Supported"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence Required"
            case .modelNotReady:
                return "Model Downloading"
            case .unknown:
                return "Not Available"
            }
        }
        
        var description: String {
            switch self {
            case .deviceNotEligible:
                return "Spot requires Apple Intelligence, which is only available on certain devices."
            case .appleIntelligenceNotEnabled:
                return "Spot requires Apple Intelligence to be enabled on your device."
            case .modelNotReady:
                return "The AI model is still downloading. This may take a few minutes."
            case .unknown:
                return "Apple Intelligence is not available on this device."
            }
        }
        
        var systemImage: String {
            switch self {
            case .deviceNotEligible:
                return "iphone.slash"
            case .appleIntelligenceNotEnabled:
                return "brain"
            case .modelNotReady:
                return "arrow.down.circle"
            case .unknown:
                return "exclamationmark.triangle"
            }
        }
        
        var showRetryButton: Bool {
            switch self {
            case .modelNotReady:
                return true
            default:
                return false
            }
        }
    }
    
    var onRetry: (() -> Void)?
    
    var body: some View {
        ZStack {
            SpotTheme.canvas
                .ignoresSafeArea()
            
            VStack(spacing: SpotTheme.Spacing.xl) {
                Spacer()
                
                // Icon
                Image(systemName: reason.systemImage)
                    .font(.system(size: 64))
                    .foregroundStyle(SpotTheme.clay.opacity(0.6))
                
                // Title & Description
                VStack(spacing: SpotTheme.Spacing.sm) {
                    Text(reason.title)
                        .font(SpotTheme.Typography.title)
                        .foregroundStyle(SpotTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(reason.description)
                        .font(SpotTheme.Typography.body)
                        .foregroundStyle(SpotTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SpotTheme.Spacing.xl)
                }
                
                // Supported Devices Section (only for device not eligible)
                if reason == .deviceNotEligible {
                    supportedDevicesSection
                }
                
                // Instructions for enabling Apple Intelligence
                if reason == .appleIntelligenceNotEnabled {
                    enableInstructionsSection
                }
                
                // Retry button for model downloading
                if reason.showRetryButton, let onRetry = onRetry {
                    Button(action: onRetry) {
                        Text("Check Again")
                            .font(SpotTheme.Typography.headline)
                            .foregroundStyle(SpotTheme.onClay)
                            .padding(.horizontal, SpotTheme.Spacing.xl)
                            .padding(.vertical, SpotTheme.Spacing.sm)
                            .background(SpotTheme.clay)
                            .clipShape(Capsule())
                    }
                    .padding(.top, SpotTheme.Spacing.md)
                }
                
                Spacer()
                Spacer()
            }
            .padding(SpotTheme.Spacing.lg)
        }
    }
    
    // MARK: - Supported Devices
    
    private var supportedDevicesSection: some View {
        VStack(spacing: SpotTheme.Spacing.sm) {
            Text("Supported Devices")
                .font(SpotTheme.Typography.headline)
                .foregroundStyle(SpotTheme.textPrimary)
            
            VStack(alignment: .leading, spacing: SpotTheme.Spacing.xs) {
                deviceRow(icon: "iphone", text: "iPhone 15 Pro, 15 Pro Max, or newer")
                deviceRow(icon: "ipad", text: "iPad with M1 chip or newer")
                deviceRow(icon: "laptopcomputer", text: "Mac with Apple Silicon")
            }
            .padding(SpotTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SpotTheme.Radius.medium)
                    .fill(SpotTheme.glassTint.opacity(0.3))
            )
        }
        .padding(.top, SpotTheme.Spacing.lg)
    }
    
    private func deviceRow(icon: String, text: String) -> some View {
        HStack(spacing: SpotTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(SpotTheme.sage)
                .frame(width: 24)
            
            Text(text)
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textSecondary)
        }
    }
    
    // MARK: - Enable Instructions
    
    private var enableInstructionsSection: some View {
        VStack(spacing: SpotTheme.Spacing.sm) {
            Text("How to Enable")
                .font(SpotTheme.Typography.headline)
                .foregroundStyle(SpotTheme.textPrimary)
            
            VStack(alignment: .leading, spacing: SpotTheme.Spacing.xs) {
                instructionRow(number: 1, text: "Open Settings")
                instructionRow(number: 2, text: "Tap Apple Intelligence & Siri")
                instructionRow(number: 3, text: "Turn on Apple Intelligence")
            }
            .padding(SpotTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: SpotTheme.Radius.medium)
                    .fill(SpotTheme.glassTint.opacity(0.3))
            )
        }
        .padding(.top, SpotTheme.Spacing.lg)
    }
    
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: SpotTheme.Spacing.sm) {
            Text("\(number)")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.onClay)
                .frame(width: 20, height: 20)
                .background(Circle().fill(SpotTheme.sage))
            
            Text(text)
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview("Device Not Eligible") {
    IncompatibleDeviceView(reason: .deviceNotEligible)
}

#Preview("Apple Intelligence Not Enabled") {
    IncompatibleDeviceView(reason: .appleIntelligenceNotEnabled)
}

#Preview("Model Downloading") {
    IncompatibleDeviceView(reason: .modelNotReady, onRetry: {})
}

#Preview("Dark Mode") {
    IncompatibleDeviceView(reason: .deviceNotEligible)
        .preferredColorScheme(.dark)
}

