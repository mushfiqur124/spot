import SwiftUI

struct SetLoggedCard: View {
    let info: LoggedExerciseInfo
    let onEdit: ((LoggedExerciseInfo.ExerciseEntry, String, [(weight: Double, reps: Int)]) -> Void)?
    
    // Animation states
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9
    
    init(info: LoggedExerciseInfo, onEdit: ((LoggedExerciseInfo.ExerciseEntry, String, [(weight: Double, reps: Int)]) -> Void)? = nil) {
        self.info = info
        self.onEdit = onEdit
    }
    
    var body: some View {
        VStack(spacing: SpotTheme.Spacing.sm) {
            ForEach(info.exercises) { exercise in
                ExerciseLoggedRow(exercise: exercise, onEdit: onEdit)
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.md)
        .opacity(opacity)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                opacity = 1
                scale = 1
            }
        }
    }
}

// MARK: - Exercise Row

private struct ExerciseLoggedRow: View {
    let exercise: LoggedExerciseInfo.ExerciseEntry
    let onEdit: ((LoggedExerciseInfo.ExerciseEntry, String, [(weight: Double, reps: Int)]) -> Void)?
    
    @State private var showEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: SpotTheme.Spacing.sm) {
            // Header with exercise name and checkmark
            HStack(spacing: SpotTheme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SpotTheme.sage)
                
                Text(exercise.exerciseName)
                    .font(SpotTheme.Typography.headline)
                    .foregroundStyle(SpotTheme.textPrimary)
                
                Spacer()
                
                if exercise.isPR {
                    PRBadge()
                }
            }
            
            // Sets pills - same style as header
            HStack(spacing: SpotTheme.Spacing.xs) {
                ForEach(exercise.sets.prefix(5)) { set in
                    SetPill(set: set)
                }
                
                if exercise.sets.count > 5 {
                    Text("+\(exercise.sets.count - 5)")
                        .font(SpotTheme.Typography.caption)
                        .foregroundStyle(SpotTheme.textSecondary)
                }
            }
            
            // Bottom row: PR callout and edit button
            HStack(alignment: .center) {
                // PR callout if applicable
                if exercise.isPR, let previous = exercise.previousBest {
                    HStack(spacing: SpotTheme.Spacing.xxs) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(SpotTheme.sage)
                        
                        Text("Previous best: \(Int(previous)) lbs")
                            .font(SpotTheme.Typography.caption)
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Edit button - bottom right
                if onEdit != nil {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(SpotTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(SpotTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: SpotTheme.Radius.medium, style: .continuous)
                .fill(SpotTheme.sage.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: SpotTheme.Radius.medium, style: .continuous)
                        .strokeBorder(SpotTheme.sage.opacity(0.2), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showEditSheet) {
            EditExerciseSheet(exercise: exercise) { newName, updatedSets in
                onEdit?(exercise, newName, updatedSets)
            }
        }
    }
}

// MARK: - Set Pill

private struct SetPill: View {
    let set: LoggedExerciseInfo.LoggedSetInfo
    
    var body: some View {
        HStack(spacing: 2) {
            Text(set.quickSummary)
                .font(SpotTheme.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(set.isPR ? SpotTheme.sage : SpotTheme.textSecondary)
            
            if set.isPR {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(SpotTheme.sage)
            }
        }
        .padding(.horizontal, SpotTheme.Spacing.xs)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(set.isPR ? SpotTheme.sage.opacity(0.15) : SpotTheme.textPrimary.opacity(0.05))
        )
    }
}

// MARK: - Preview

#Preview("Set Logged Card - Single") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        SetLoggedCard(info: .single(
            exerciseName: "Bench Press",
            sets: [
                .init(setNumber: 1, weight: 135, reps: 10, isPR: false),
                .init(setNumber: 2, weight: 155, reps: 8, isPR: false),
                .init(setNumber: 3, weight: 175, reps: 6, isPR: true)
            ],
            isPR: true,
            previousBest: 170
        ))
    }
}

#Preview("Set Logged Card - Multiple") {
    ZStack {
        SpotTheme.canvas
            .ignoresSafeArea()
        
        SetLoggedCard(info: LoggedExerciseInfo(exercises: [
            .init(
                exerciseName: "Bench Press",
                sets: [
                    .init(setNumber: 1, weight: 135, reps: 10, isPR: false),
                    .init(setNumber: 2, weight: 155, reps: 8, isPR: false)
                ],
                isPR: false,
                previousBest: nil
            ),
            .init(
                exerciseName: "Squats",
                sets: [
                    .init(setNumber: 1, weight: 225, reps: 5, isPR: true)
                ],
                isPR: true,
                previousBest: 215
            )
        ]))
    }
}

