//
//  SettingsView.swift
//  Spot
//
//  Settings view with profile and appearance options.
//  Glassmorphic design matching the app's aesthetic.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    
    @State private var showingProfileEditor = false
    
    private var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                SpotTheme.canvas
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: SpotTheme.Spacing.lg) {
                        // Profile Card
                        profileCard
                        
                        // Appearance Card
                        appearanceCard
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, SpotTheme.Spacing.md)
                    .padding(.top, SpotTheme.Spacing.md)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(SpotTheme.clay)
                    .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showingProfileEditor) {
                if let profile = profiles.first {
                    ProfileEditorSheet(profile: profile)
                }
            }
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        let profile = profiles.first
        
        return VStack(spacing: 0) {
            // Header
            HStack(spacing: SpotTheme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SpotTheme.clay.opacity(0.8), SpotTheme.clay.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.name ?? "User")
                        .font(SpotTheme.Typography.headline)
                        .foregroundStyle(SpotTheme.textPrimary)
                    
                    Text("Profile")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
                
                Spacer()
                
                Button {
                    showingProfileEditor = true
                } label: {
                    Text("Edit")
                        .font(SpotTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(SpotTheme.clay)
                }
            }
            .padding(SpotTheme.Spacing.md)
            
            Divider()
                .background(SpotTheme.textSecondary.opacity(0.1))
            
            // Stats
            HStack(spacing: SpotTheme.Spacing.lg) {
                // Height
                VStack(spacing: 4) {
                    Text("Height")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                    
                    Text(profile?.formattedHeight ?? "—")
                        .font(SpotTheme.Typography.headline)
                        .foregroundStyle(SpotTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 30)
                    .background(SpotTheme.textSecondary.opacity(0.2))
                
                // Weight
                VStack(spacing: 4) {
                    Text("Weight")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                    
                    Text(profile?.formattedWeight ?? "—")
                        .font(SpotTheme.Typography.headline)
                        .foregroundStyle(SpotTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(SpotTheme.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SpotTheme.textSecondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(SpotTheme.textSecondary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Appearance Card
    
    private var appearanceCard: some View {
        let currentMode = AppearanceMode(rawValue: appearanceModeRaw) ?? .system
        
        return VStack(spacing: SpotTheme.Spacing.md) {
            // Header
            HStack(spacing: SpotTheme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [SpotTheme.sage, SpotTheme.sage.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: currentMode.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Appearance")
                        .font(SpotTheme.Typography.headline)
                        .foregroundStyle(SpotTheme.textPrimary)
                    
                    Text(currentMode.description)
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
                
                Spacer()
            }
            
            // Mode Picker
            Picker("Appearance Mode", selection: Binding(
                get: { AppearanceMode(rawValue: appearanceModeRaw) ?? .system },
                set: { appearanceModeRaw = $0.rawValue }
            )) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.rawValue)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(SpotTheme.sage)
        }
        .padding(SpotTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SpotTheme.textSecondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(SpotTheme.textSecondary.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Profile Editor Sheet

struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var profile: UserProfile
    
    @State private var heightFeet: Int
    @State private var heightInches: Int
    @State private var weightText: String
    
    init(profile: UserProfile) {
        self.profile = profile
        
        // Initialize height from profile
        let totalInches = Int(profile.heightInches ?? 70) // Default to 5'10"
        _heightFeet = State(initialValue: totalInches / 12)
        _heightInches = State(initialValue: totalInches % 12)
        
        // Initialize weight
        if let weight = profile.weightLbs {
            _weightText = State(initialValue: String(Int(weight)))
        } else {
            _weightText = State(initialValue: "")
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SpotTheme.canvas
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: SpotTheme.Spacing.lg) {
                        // Height Section
                        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
                            Text("Height")
                                .font(SpotTheme.Typography.headline)
                                .foregroundStyle(SpotTheme.textPrimary)
                            
                            HStack(spacing: SpotTheme.Spacing.md) {
                                // Feet picker
                                VStack(spacing: SpotTheme.Spacing.xs) {
                                    Picker("Feet", selection: $heightFeet) {
                                        ForEach(4...7, id: \.self) { feet in
                                            Text("\(feet)").tag(feet)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 120)
                                    
                                    Text("ft")
                                        .font(SpotTheme.Typography.caption)
                                        .foregroundStyle(SpotTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(SpotTheme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(SpotTheme.textSecondary.opacity(0.05))
                                )
                                
                                // Inches picker
                                VStack(spacing: SpotTheme.Spacing.xs) {
                                    Picker("Inches", selection: $heightInches) {
                                        ForEach(0...11, id: \.self) { inches in
                                            Text("\(inches)").tag(inches)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(height: 120)
                                    
                                    Text("in")
                                        .font(SpotTheme.Typography.caption)
                                        .foregroundStyle(SpotTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(SpotTheme.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(SpotTheme.textSecondary.opacity(0.05))
                                )
                            }
                        }
                        .padding(SpotTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(SpotTheme.textSecondary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(SpotTheme.textSecondary.opacity(0.1), lineWidth: 1)
                                )
                        )
                        
                        // Weight Section
                        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
                            Text("Weight")
                                .font(SpotTheme.Typography.headline)
                                .foregroundStyle(SpotTheme.textPrimary)
                            
                            HStack {
                                TextField("180", text: $weightText)
                                    .font(SpotTheme.Typography.title2)
                                    .keyboardType(.numberPad)
                                    .foregroundStyle(SpotTheme.textPrimary)
                                
                                Spacer()
                                
                                Text("lbs")
                                    .font(SpotTheme.Typography.body)
                                    .foregroundStyle(SpotTheme.textSecondary)
                            }
                            .padding(SpotTheme.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(SpotTheme.textSecondary.opacity(0.05))
                            )
                        }
                        .padding(SpotTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(SpotTheme.textSecondary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(SpotTheme.textSecondary.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, SpotTheme.Spacing.md)
                    .padding(.top, SpotTheme.Spacing.md)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(SpotTheme.textSecondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .foregroundStyle(SpotTheme.clay)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveProfile() {
        // Update height
        let totalInches = Double(heightFeet * 12 + heightInches)
        profile.heightInches = totalInches
        
        // Update weight
        if let weight = Double(weightText) {
            profile.weightLbs = weight
        } else if weightText.isEmpty {
            profile.weightLbs = nil
        }
        
        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
