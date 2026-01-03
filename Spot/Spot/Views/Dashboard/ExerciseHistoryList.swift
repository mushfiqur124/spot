//
//  ExerciseHistoryList.swift
//  Spot
//
//  Expandable list of all exercises with history.
//  Shows dates performed, sets, reps, and PRs.
//

import SwiftUI
import SwiftData

struct ExerciseHistoryList: View {
    let exercises: [Exercise]
    
    @State private var expandedExerciseID: UUID?
    @State private var searchText: String = ""
    @State private var editingExercise: Exercise?
    @State private var editedName: String = ""
    @State private var showingRenameAlert = false
    @State private var exerciseToDelete: Exercise?
    @State private var showingDeleteConfirmation = false
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
            // Header
            HStack {
                Text("Exercises")
                    .font(SpotTheme.Typography.headline)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Spacer()
                
                Text("\(exercisesWithHistory.count) total")
                    .font(SpotTheme.Typography.caption)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            // Search
            HStack(spacing: SpotTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(SpotTheme.textSecondary)
                
                TextField("Search exercises...", text: $searchText)
                    .font(SpotTheme.Typography.body)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, SpotTheme.Spacing.sm)
            .padding(.vertical, SpotTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: SpotTheme.Radius.small)
                    .fill(SpotTheme.textPrimary.opacity(0.05))
            )
            
            // Exercise list
            if filteredExercises.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredExercises.enumerated()), id: \.element.id) { index, exercise in
                        ExerciseHistoryRow(
                            exercise: exercise,
                            isExpanded: expandedExerciseID == exercise.id
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if expandedExerciseID == exercise.id {
                                    expandedExerciseID = nil
                                } else {
                                    expandedExerciseID = exercise.id
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                exerciseToDelete = exercise
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                startEditing(exercise)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(SpotTheme.clay)
                        }
                        
                        // Add divider between exercises (not after the last one)
                        if index < filteredExercises.count - 1 {
                            Divider()
                                .background(SpotTheme.textSecondary.opacity(0.1))
                                .padding(.leading, SpotTheme.Spacing.sm)
                        }
                    }
                }
            }
        }
        .padding(SpotTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SpotTheme.Radius.medium, style: .continuous)
                .fill(SpotTheme.textPrimary.opacity(0.03))
        )
        .alert("Rename Exercise", isPresented: $showingRenameAlert) {
            TextField("Exercise name", text: $editedName)
                .autocapitalization(.words)
            
            Button("Cancel", role: .cancel) {
                editingExercise = nil
            }
            
            Button("Save") {
                saveRename()
            }
            .disabled(editedName.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Enter a new name for this exercise")
        }
        .alert("Delete Exercise", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                exerciseToDelete = nil
            }
            
            Button("Delete", role: .destructive) {
                deleteExercise()
            }
        } message: {
            if let exercise = exerciseToDelete {
                Text("Are you sure you want to delete \"\(exercise.name)\"? All workout history for this exercise will be permanently removed.")
            }
        }
    }
    
    // MARK: - Actions
    
    private func startEditing(_ exercise: Exercise) {
        editingExercise = exercise
        editedName = exercise.name
        showingRenameAlert = true
    }
    
    private func saveRename() {
        guard let exercise = editingExercise else { return }
        
        let trimmedName = editedName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Check if name already exists (case-insensitive)
        let nameExists = exercisesWithHistory.contains {
            $0.id != exercise.id && $0.name.lowercased() == trimmedName.lowercased()
        }
        
        if !nameExists {
            exercise.name = trimmedName
            try? modelContext.save()
        }
        
        editingExercise = nil
    }
    
    private func deleteExercise() {
        guard let exercise = exerciseToDelete else { return }
        
        modelContext.delete(exercise)
        try? modelContext.save()
        
        exerciseToDelete = nil
    }
    
    // MARK: - Computed
    
    private var exercisesWithHistory: [Exercise] {
        exercises.filter { !$0.history.isEmpty }
            .sorted { $0.name < $1.name }
    }
    
    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercisesWithHistory
        }
        let lowercased = searchText.lowercased()
        return exercisesWithHistory.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.muscleGroup.lowercased().contains(lowercased)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: SpotTheme.Spacing.sm) {
            Image(systemName: searchText.isEmpty ? "dumbbell" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.5))
            
            Text(searchText.isEmpty ? "No exercises yet" : "No matches found")
                .font(SpotTheme.Typography.subheadline)
                .foregroundStyle(SpotTheme.textSecondary)
            
            Text(searchText.isEmpty ? "Start logging workouts to build your history!" : "Try a different search term")
                .font(SpotTheme.Typography.caption)
                .foregroundStyle(SpotTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpotTheme.Spacing.xl)
    }
}

// MARK: - Exercise History Row

private struct ExerciseHistoryRow: View {
    let exercise: Exercise
    let isExpanded: Bool
    let onTap: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button(action: onTap) {
                HStack(spacing: SpotTheme.Spacing.sm) {
                    // Exercise info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: SpotTheme.Spacing.xs) {
                            Text(exercise.name)
                                .font(SpotTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(SpotTheme.textPrimary)
                            
                            if let maxWeight = exercise.allTimeMaxWeight, maxWeight > 0 {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(SpotTheme.sage)
                            }
                        }
                        
                        HStack(spacing: SpotTheme.Spacing.xs) {
                            Text(exercise.muscleGroup)
                                .font(SpotTheme.Typography.caption)
                                .foregroundStyle(SpotTheme.clay)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(SpotTheme.clay.opacity(0.15))
                                )
                            
                            Text("\(exercise.history.count) session\(exercise.history.count == 1 ? "" : "s")")
                                .font(SpotTheme.Typography.caption)
                                .foregroundStyle(SpotTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // PR badge
                    if let maxWeight = exercise.allTimeMaxWeight, maxWeight > 0 {
                        Text("\(Int(maxWeight)) lbs")
                            .font(SpotTheme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(SpotTheme.sage)
                            .padding(.horizontal, SpotTheme.Spacing.xs)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(SpotTheme.sage.opacity(0.1))
                            )
                    }
                    
                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SpotTheme.textSecondary)
                }
                .padding(.vertical, SpotTheme.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SpotTheme.Radius.small)
                .fill(isExpanded ? SpotTheme.textPrimary.opacity(0.03) : Color.clear)
        )
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
            Divider()
                .padding(.bottom, SpotTheme.Spacing.xs)
            
            // Recent sessions
            ForEach(recentSessions.prefix(5), id: \.id) { workoutExercise in
                sessionRow(for: workoutExercise)
            }
            
            if recentSessions.count > 5 {
                Text("+ \(recentSessions.count - 5) more sessions")
                    .font(SpotTheme.Typography.caption)
                    .foregroundStyle(SpotTheme.textSecondary)
                    .padding(.top, SpotTheme.Spacing.xxs)
            }
        }
        .padding(.bottom, SpotTheme.Spacing.sm)
    }
    
    private func sessionRow(for workoutExercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.xxs) {
            // Date
            if let session = workoutExercise.session {
                Text(dateFormatter.string(from: session.startTime))
                    .font(SpotTheme.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            // Sets
            HStack(spacing: SpotTheme.Spacing.xs) {
                ForEach(workoutExercise.orderedSets.prefix(5)) { set in
                    HStack(spacing: 2) {
                        Text(set.quickSummary)
                            .font(SpotTheme.Typography.caption)
                            .foregroundStyle(set.isPR ? SpotTheme.sage : SpotTheme.textPrimary)
                        
                        if set.isPR {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(SpotTheme.sage)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(set.isPR ? SpotTheme.sage.opacity(0.1) : SpotTheme.textPrimary.opacity(0.05))
                    )
                }
                
                if workoutExercise.sets.count > 5 {
                    Text("+\(workoutExercise.sets.count - 5)")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
            }
        }
    }
    
    private var recentSessions: [WorkoutExercise] {
        exercise.history
            .sorted { ($0.session?.startTime ?? .distantPast) > ($1.session?.startTime ?? .distantPast) }
    }
}

// MARK: - Preview

#Preview("Exercise History") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        ScrollView {
            ExerciseHistoryList(exercises: [])
                .padding()
        }
    }
}

