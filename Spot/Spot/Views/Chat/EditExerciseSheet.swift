//
//  EditExerciseSheet.swift
//  Spot
//
//  Sheet for editing logged exercise data.
//  Allows users to modify weight, reps, and exercise name.
//

import SwiftUI
import SwiftData

struct EditExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let exercise: LoggedExerciseInfo.ExerciseEntry
    let onSave: (String, [(weight: Double, reps: Int)]) -> Void
    let onDelete: ((String) -> Void)?
    
    @State private var exerciseName: String
    @State private var editableSets: [EditableSet]
    @State private var showExercisePicker = false
    @State private var searchQuery = ""
    
    @State private var matchingService: ExerciseMatchingService?
    @State private var searchResults: [(exercise: Exercise, confidence: Double)] = []
    
    struct EditableSet: Identifiable {
        let id = UUID()
        var weight: Double
        var reps: Int
    }
    
    init(
        exercise: LoggedExerciseInfo.ExerciseEntry,
        onSave: @escaping (String, [(weight: Double, reps: Int)]) -> Void,
        onDelete: ((String) -> Void)? = nil
    ) {
        self.exercise = exercise
        self.onSave = onSave
        self.onDelete = onDelete
        _exerciseName = State(initialValue: exercise.exerciseName)
        _editableSets = State(initialValue: exercise.sets.map { 
            EditableSet(weight: $0.weight, reps: $0.reps) 
        })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Exercise Name Section
                Section {
                    Button {
                        showExercisePicker = true
                    } label: {
                        HStack {
                            Text("Exercise")
                                .foregroundStyle(SpotTheme.textSecondary)
                            Spacer()
                            Text(exerciseName)
                                .foregroundStyle(SpotTheme.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(SpotTheme.textSecondary)
                        }
                    }
                } header: {
                    Text("Exercise")
                }
                
                // Sets Section
                Section {
                    ForEach($editableSets) { $set in
                        SetEditRow(set: $set)
                    }
                    .onDelete(perform: deleteSet)
                } header: {
                    Text("Sets")
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let setsData = editableSets.map { (weight: $0.weight, reps: $0.reps) }
                        onSave(exerciseName, setsData)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet(
                    currentName: exerciseName,
                    searchResults: searchResults,
                    searchQuery: $searchQuery,
                    onSearch: performSearch,
                    onSelect: { name in
                        exerciseName = name
                        showExercisePicker = false
                    },
                    onDelete: onDelete
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                matchingService = ExerciseMatchingService(modelContext: modelContext)
            }
        }
    }
    
    private func performSearch(_ query: String) {
        guard let service = matchingService else { return }
        if query.isEmpty {
            searchResults = []
        } else {
            searchResults = service.searchExercises(query: query)
        }
    }
    
    private func deleteSet(at offsets: IndexSet) {
        editableSets.remove(atOffsets: offsets)
    }
}

// MARK: - Set Edit Row

private struct SetEditRow: View {
    @Binding var set: EditExerciseSheet.EditableSet
    
    var body: some View {
        HStack(spacing: SpotTheme.Spacing.md) {
            // Weight field
            HStack(spacing: SpotTheme.Spacing.xs) {
                Text("Weight")
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
                
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(SpotTheme.textSecondary.opacity(0.1))
                    .foregroundStyle(SpotTheme.textPrimary)
                    .cornerRadius(8)
                    .frame(width: 70)
                
                Text("lbs")
                    .font(SpotTheme.Typography.caption)
                    .foregroundStyle(SpotTheme.textSecondary)
            }
            
            Spacer()
            
            // Reps field
            HStack(spacing: SpotTheme.Spacing.xs) {
                Text("Reps")
                    .font(SpotTheme.Typography.subheadline)
                    .foregroundStyle(SpotTheme.textSecondary)
                
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(SpotTheme.textSecondary.opacity(0.1))
                    .foregroundStyle(SpotTheme.textPrimary)
                    .cornerRadius(8)
                    .frame(width: 60)
            }
        }
    }
}

// MARK: - Exercise Picker Sheet

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Live query for all exercises, ensuring instant updates
    @Query(filter: #Predicate<Exercise> { !$0.isHidden }, sort: [SortDescriptor(\Exercise.name)])
    private var allExercises: [Exercise]
    
    let currentName: String
    let searchResults: [(exercise: Exercise, confidence: Double)]
    @Binding var searchQuery: String
    let onSearch: (String) -> Void
    let onSelect: (String) -> Void
    let onDelete: ((String) -> Void)?
    
    @State private var editingExercise: Exercise?
    @State private var editedName: String = ""
    @State private var showingRenameAlert = false
    @State private var exerciseToDelete: Exercise?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Search field
                Section {
                    TextField("Search exercises...", text: $searchQuery)
                        .onChange(of: searchQuery) { _, newValue in
                            onSearch(newValue)
                        }
                }
                
                // Keep current name option
                if !searchQuery.isEmpty && !exerciseExists(searchQuery) {
                    Section {
                        Button {
                            onSelect(searchQuery)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(SpotTheme.sage)
                                Text("Create new: \"\(searchQuery)\"")
                                    .foregroundStyle(SpotTheme.textPrimary)
                            }
                        }
                    } header: {
                        Text("New Exercise")
                    }
                }
                
                // Search results
                if !searchResults.isEmpty {
                    Section {
                        ForEach(searchResults, id: \.exercise.id) { result in
                            ExerciseRow(
                                exercise: result.exercise,
                                currentName: currentName,
                                isBestMatch: result.confidence >= 0.8,
                                onSelect: onSelect,
                                onDelete: { exercise in
                                    exerciseToDelete = exercise
                                    showingDeleteConfirmation = true
                                },
                                onEdit: { exercise in
                                    startEditing(exercise)
                                }
                            )
                        }
                    } header: {
                        Text("Matching Exercises")
                    }
                }
                
                // All exercises when no search
                // Using @Query backed allExercises here ensures this list is always fresh
                if searchQuery.isEmpty {
                    Section {
                        ForEach(allExercises) { exercise in
                            ExerciseRow(
                                exercise: exercise,
                                currentName: currentName,
                                isBestMatch: false,
                                onSelect: onSelect,
                                onDelete: { exercise in
                                    exerciseToDelete = exercise
                                    showingDeleteConfirmation = true
                                },
                                onEdit: { exercise in
                                    startEditing(exercise)
                                }
                            )
                        }
                    } header: {
                        Text("Your Exercises")
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
                    Text("Are you sure you want to delete \"\(exercise.name)\" from your list? Your history for this exercise will be preserved but hidden.")
                }
            }
        }
    }
    
    private func exerciseExists(_ name: String) -> Bool {
        allExercises.contains { $0.name.lowercased() == name.lowercased() }
    }
    
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
        let nameExists = allExercises.contains { 
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
        
        let name = exercise.name
        
        // Notify parent about deletion before physically deleting
        onDelete?(name)
        
        // Soft delete (hide) instead of hard delete
        exercise.isHidden = true
        try? modelContext.save()
        
        exerciseToDelete = nil
    }
}

// MARK: - Exercise Row Component

private struct ExerciseRow: View {
    let exercise: Exercise
    let currentName: String
    let isBestMatch: Bool
    let onSelect: (String) -> Void
    let onDelete: (Exercise) -> Void
    let onEdit: (Exercise) -> Void
    
    var body: some View {
        Button {
            onSelect(exercise.name)
        } label: {
            HStack {
                Text(exercise.name)
                    .foregroundStyle(SpotTheme.textPrimary)
                Spacer()
                if isBestMatch {
                    Text("Best match")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.sage)
                } else if exercise.name == currentName {
                    Image(systemName: "checkmark")
                        .foregroundStyle(SpotTheme.sage)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete(exercise)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                onEdit(exercise)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(SpotTheme.clay)
        }
    }
}

// MARK: - Preview

#Preview {
    EditExerciseSheet(
        exercise: LoggedExerciseInfo.ExerciseEntry(
            exerciseName: "Bench Press",
            sets: [
                .init(setNumber: 1, weight: 135, reps: 10, isPR: false),
                .init(setNumber: 2, weight: 155, reps: 8, isPR: false)
            ],
            isPR: false,
            previousBest: nil
        )
    ) { name, sets in
        print("Saved: \(name) with \(sets.count) sets")
    }
}
