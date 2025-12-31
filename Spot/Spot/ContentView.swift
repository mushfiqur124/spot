//
//  ContentView.swift
//  Spot
//
//  Main entry point view - checks device compatibility and displays
//  the appropriate view (chat or incompatible device screen).
//

import SwiftUI
import SwiftData
import FoundationModels

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var compatibilityStatus: CompatibilityStatus = .checking
    @State private var showOnboarding: Bool = false
    @State private var userProfile: UserProfile?
    @State private var showDashboard: Bool = false
    
    enum CompatibilityStatus {
        case checking
        case compatible
        case incompatible(IncompatibleDeviceView.IncompatibilityReason)
    }
    
    var body: some View {
        Group {
            switch compatibilityStatus {
            case .checking:
                loadingView
            case .compatible:
                if showOnboarding {
                    OnboardingView {
                        // Onboarding complete - reload profile
                        loadUserProfile()
                        showOnboarding = false
                    }
                } else if #available(iOS 26.0, *) {
                    if showDashboard {
                        DashboardView(
                            userProfile: userProfile,
                            onDismiss: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showDashboard = false
                                }
                            }
                        )
                        .transition(.move(edge: .trailing))
                    } else {
                        ChatView(
                            modelContext: modelContext,
                            userProfile: userProfile,
                            onOpenDashboard: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showDashboard = true
                                }
                            }
                        )
                        .transition(.move(edge: .leading))
                    }
                } else {
                    // This shouldn't happen since we check availability first
                    IncompatibleDeviceView(reason: .deviceNotEligible)
                }
            case .incompatible(let reason):
                IncompatibleDeviceView(reason: reason) {
                    // Retry callback
                    checkCompatibility()
                }
            }
        }
        .task {
            checkCompatibility()
            loadUserProfile()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ZStack {
            SpotTheme.canvas
                .ignoresSafeArea()
            
            VStack(spacing: SpotTheme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(SpotTheme.clay)
                
                Text("Checking compatibility...")
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
        }
    }
    
    // MARK: - Compatibility Check
    
    private func checkCompatibility() {
        // Check if iOS 26+ is available
        guard #available(iOS 26.0, *) else {
            compatibilityStatus = .incompatible(.deviceNotEligible)
            return
        }
        
        // Check Foundation Models availability
        let availability = LLMService.checkAvailability()
        
        switch availability {
        case .available:
            compatibilityStatus = .compatible
        case .deviceNotEligible:
            compatibilityStatus = .incompatible(.deviceNotEligible)
        case .appleIntelligenceNotEnabled:
            compatibilityStatus = .incompatible(.appleIntelligenceNotEnabled)
        case .modelNotReady:
            compatibilityStatus = .incompatible(.modelNotReady)
        case .unknown:
            compatibilityStatus = .incompatible(.unknown)
        }
    }
    
    // MARK: - User Profile
    
    private func loadUserProfile() {
        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        if let profiles = try? modelContext.fetch(descriptor),
           let profile = profiles.first,
           profile.hasCompletedOnboarding {
            userProfile = profile
            showOnboarding = false
        } else {
            showOnboarding = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}

#Preview("Dark Mode") {
    ContentView()
        .modelContainer(SampleData.previewContainer)
        .preferredColorScheme(.dark)
}
