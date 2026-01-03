//
//  ContentView.swift
//  Spot
//
//  Main entry point view - displays the appropriate view
//  (chat, onboarding, or error screen based on state).
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isReady: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var userProfile: UserProfile?
    @State private var showDashboard: Bool = false
    @State private var initializationError: String? = nil
    
    var body: some View {
        Group {
            if !isReady {
                loadingView
            } else if let error = initializationError {
                errorView(message: error)
            } else if showOnboarding {
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
                // iOS version too old
                errorView(message: "This app requires iOS 26 or later.")
            }
        }
        .task {
            await initialize()
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
                
                Text("Loading...")
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        ZStack {
            SpotTheme.canvas
                .ignoresSafeArea()
            
            VStack(spacing: SpotTheme.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(SpotTheme.clay.opacity(0.7))
                
                Text("Setup Required")
                    .font(SpotTheme.Typography.title)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Text(message)
                    .font(SpotTheme.Typography.body)
                    .foregroundStyle(SpotTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpotTheme.Spacing.xl)
            }
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        // Load user profile first
        loadUserProfile()
        
        // Small delay to ensure smooth transition
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        isReady = true
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
