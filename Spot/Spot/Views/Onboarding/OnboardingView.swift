//
//  OnboardingView.swift
//  Spot
//
//  Multi-step onboarding flow to collect user information.
//  Name is required, other fields are optional.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - State
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var name: String = ""
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 10
    @State private var weight: String = ""
    @State private var selectedGoals: Set<UserProfile.FitnessGoal> = []
    
    // Callbacks
    var onComplete: () -> Void
    
    // MARK: - Onboarding Steps
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case name = 1
        case physicalStats = 2
        case goals = 3
        
        var title: String {
            switch self {
            case .welcome: return ""
            case .name: return "What should I call you?"
            case .physicalStats: return "Quick stats"
            case .goals: return "What's your goal?"
            }
        }
        
        var subtitle: String {
            switch self {
            case .welcome: return ""
            case .name: return ""
            case .physicalStats: return "Required for tracking bodyweight exercises"
            case .goals: return "Select all that apply"
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            SpotTheme.canvas
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator (hide on welcome)
                if currentStep != .welcome {
                    progressIndicator
                        .padding(.top, SpotTheme.Spacing.md)
                }
                
                Spacer()
                
                // Content for current step
                stepContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                
                Spacer()
                
                // Navigation buttons
                navigationButtons
                    .padding(.horizontal, SpotTheme.Spacing.lg)
                    .padding(.bottom, SpotTheme.Spacing.xl)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: SpotTheme.Spacing.xs) {
            ForEach(OnboardingStep.allCases.dropFirst(), id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? SpotTheme.clay : SpotTheme.clay.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.xl)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .name:
            nameStep
        case .physicalStats:
            physicalStatsStep
        case .goals:
            goalsStep
        }
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: SpotTheme.Spacing.lg) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 72))
                .foregroundStyle(SpotTheme.clay)
            
            VStack(spacing: SpotTheme.Spacing.sm) {
                Text("Hey, I'm Spot")
                    .font(SpotTheme.Typography.largeTitle)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Text("Your AI workout partner.\nLet's get you set up.")
                    .font(SpotTheme.Typography.body)
                    .foregroundStyle(SpotTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.xl)
    }
    
    // MARK: - Name Step
    
    private var nameStep: some View {
        VStack(spacing: SpotTheme.Spacing.lg) {
            VStack(spacing: SpotTheme.Spacing.xs) {
                Text(currentStep.title)
                    .font(SpotTheme.Typography.title)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Text(currentStep.subtitle)
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            TextField("Your name", text: $name)
                .font(SpotTheme.Typography.title2)
                .multilineTextAlignment(.center)
                .foregroundStyle(SpotTheme.textPrimary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: SpotTheme.Radius.medium)
                        .fill(SpotTheme.textPrimary.opacity(0.05))
                )
                .padding(.horizontal, SpotTheme.Spacing.xl)
        }
    }
    
    // MARK: - Physical Stats Step
    
    private var physicalStatsStep: some View {
        VStack(spacing: SpotTheme.Spacing.lg) {
            VStack(spacing: SpotTheme.Spacing.xs) {
                Text(currentStep.title)
                    .font(SpotTheme.Typography.title)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Text(currentStep.subtitle)
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            VStack(spacing: SpotTheme.Spacing.md) {
                // Height picker
                VStack(alignment: .leading, spacing: SpotTheme.Spacing.xs) {
                    Text("Height")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                    
                    HStack(spacing: SpotTheme.Spacing.sm) {
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(4...7, id: \.self) { feet in
                                Text("\(feet) ft").tag(feet)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 100)
                        .clipped()
                        
                        Picker("Inches", selection: $heightInches) {
                            ForEach(0...11, id: \.self) { inches in
                                Text("\(inches) in").tag(inches)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 100)
                        .clipped()
                    }
                }
                
                // Weight input
                VStack(alignment: .leading, spacing: SpotTheme.Spacing.xs) {
                    Text("Weight (lbs)")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                    
                    TextField("180", text: $weight)
                        .font(SpotTheme.Typography.title2)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(SpotTheme.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: SpotTheme.Radius.medium)
                                .fill(SpotTheme.textPrimary.opacity(0.05))
                        )
                }
            }
            .padding(.horizontal, SpotTheme.Spacing.xl)
        }
    }
    
    // MARK: - Goals Step
    
    private var goalsStep: some View {
        VStack(spacing: SpotTheme.Spacing.lg) {
            VStack(spacing: SpotTheme.Spacing.xs) {
                Text(currentStep.title)
                    .font(SpotTheme.Typography.title)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Text(currentStep.subtitle)
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SpotTheme.Spacing.sm) {
                ForEach(UserProfile.FitnessGoal.allCases, id: \.rawValue) { goal in
                    GoalCard(
                        goal: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SpotTheme.Spacing.md)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: SpotTheme.Spacing.md) {
            // Back button (hidden on welcome and name)
            if currentStep.rawValue > 1 {
                Button {
                    goToPreviousStep()
                } label: {
                    Text("Back")
                        .font(SpotTheme.Typography.headline)
                        .foregroundStyle(SpotTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpotTheme.Spacing.md)
                }
            }
            
            // Continue/Skip/Finish button
            Button {
                goToNextStep()
            } label: {
                Text(nextButtonTitle)
                    .font(SpotTheme.Typography.headline)
                    .foregroundStyle(SpotTheme.onClay)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpotTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: SpotTheme.Radius.medium)
                            .fill(canProceed ? SpotTheme.clay : SpotTheme.clay.opacity(0.5))
                    )
            }
            .disabled(!canProceed && currentStep == .name)
        }
    }
    
    // MARK: - Navigation Logic
    
    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Let's Go"
        case .name:
            return "Continue"
        case .physicalStats:
            return "Continue"
        case .goals:
            return "Finish"
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .name:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .physicalStats:
            // Require weight to be entered
            return !weight.trimmingCharacters(in: .whitespaces).isEmpty && Double(weight) != nil
        case .goals:
            return true
        }
    }
    
    private func goToNextStep() {
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        } else {
            // Complete onboarding
            saveProfile()
        }
    }
    
    private func goToPreviousStep() {
        if let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
    }
    
    private func saveProfile() {
        // Clear any old data from previous users/testing
        clearOldData()
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Calculate height in inches
        let totalHeightInches = Double(heightFeet * 12 + heightInches)
        
        // Parse weight
        let weightValue = Double(weight)
        
        let profile = UserProfile(
            name: trimmedName,
            heightInches: totalHeightInches,
            weightLbs: weightValue,
            fitnessGoals: selectedGoals.map { $0.rawValue },
            hasCompletedOnboarding: true
        )
        
        modelContext.insert(profile)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save profile: \(error)")
        }
        
        onComplete()
    }
    
    /// Clear old data when new user is created
    private func clearOldData() {
        // Delete old conversations
        let conversationDescriptor = FetchDescriptor<Conversation>()
        if let conversations = try? modelContext.fetch(conversationDescriptor) {
            for conversation in conversations {
                modelContext.delete(conversation)
            }
        }
        
        // Delete old chat messages (orphaned ones)
        let messageDescriptor = FetchDescriptor<ChatMessage>()
        if let messages = try? modelContext.fetch(messageDescriptor) {
            for message in messages {
                modelContext.delete(message)
            }
        }
        
        // Delete old workout sessions
        let sessionDescriptor = FetchDescriptor<WorkoutSession>()
        if let sessions = try? modelContext.fetch(sessionDescriptor) {
            for session in sessions {
                modelContext.delete(session)
            }
        }
        
        // Delete old user profiles (shouldn't exist, but clean up)
        let profileDescriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(profileDescriptor) {
            for profile in profiles {
                modelContext.delete(profile)
            }
        }
        
        try? modelContext.save()
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: UserProfile.FitnessGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: SpotTheme.Spacing.xs) {
                Text(goal.rawValue)
                    .font(SpotTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? SpotTheme.onClay : SpotTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpotTheme.Spacing.md)
            .padding(.horizontal, SpotTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: SpotTheme.Radius.medium)
                    .fill(isSelected ? SpotTheme.clay : SpotTheme.textPrimary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SpotTheme.Radius.medium)
                    .stroke(isSelected ? SpotTheme.clay : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView {
        print("Onboarding complete")
    }
    .modelContainer(SampleData.previewContainer)
}

