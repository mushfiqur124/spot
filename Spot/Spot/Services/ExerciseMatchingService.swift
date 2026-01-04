//
//  ExerciseMatchingService.swift
//  Spot
//
//  Handles fuzzy matching of exercise names to maintain clean data.
//  Maps variations like "MTS Incline" to "Incline Machine Press".
//

import Foundation
import SwiftData

/// Result of an exercise match attempt
struct ExerciseMatchResult {
    let exercise: Exercise?
    let confidence: Double  // 0.0 to 1.0
    let isExactMatch: Bool
    let normalizedInput: String
}

@MainActor
class ExerciseMatchingService {
    private let modelContext: ModelContext
    
    /// Minimum similarity score (0-1) required to consider a fuzzy match
    /// Set high (0.8) to avoid incorrect matches like "barbell squats" → "bicep curls"
    let fuzzyMatchThreshold: Double = 0.8
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Methods
    
    /// Find or create an exercise by name
    /// - Parameters:
    ///   - name: The user-provided exercise name
    ///   - muscleGroup: The muscle group (used if creating new)
    /// - Returns: The matched or newly created Exercise
    func findOrCreate(name: String, muscleGroup: String) -> Exercise {
        // First check for exact match, including hidden ones
        // If we find a hidden one, we should unhide it because the user is explicitly using it
        let normalized = normalize(name)
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == normalized || $0.name == name } // Simplify predicate for now
        )
        // Note: String comparison in Predicate can be tricky with normalization. 
        // We'll rely on fetching and filtering if ensuring exact case-insensitive match matters most,
        // but let's try to use findBestMatch logic which handles normalization well.
        
        let result = findBestMatch(for: name, includeHidden: true)
        
        if let exercise = result.exercise {
            // If it's an exact match (or very high confidence), use it
            if result.isExactMatch || result.confidence >= 0.95 {
                // Unhide if it was hidden
                if exercise.isHidden {
                    exercise.isHidden = false
                    try? modelContext.save()
                }
                return exercise
            }
            
            // If it's a good fuzzy match, we might want to return it, 
            // but standard behavior is to trust user input for new variations.
            // However, for "Bench Pres" -> "Bench Press", we likely want the existing one.
            if result.confidence >= fuzzyMatchThreshold {
                if exercise.isHidden {
                    exercise.isHidden = false
                    try? modelContext.save()
                }
                return exercise
            }
        }
        
        // Create new
        let newExercise = Exercise(
            name: normalizeForStorage(name),
            muscleGroup: muscleGroup
        )
        modelContext.insert(newExercise)
        return newExercise
    }
    
    /// Find the best matching exercise for a given name
    /// - Parameter name: The user-provided exercise name
    /// - Parameter includeHidden: Whether to include hidden exercises (default false)
    /// - Returns: Match result with confidence score
    func findBestMatch(for name: String, includeHidden: Bool = false) -> ExerciseMatchResult {
        let normalized = normalize(name)
        let inputWords = Set(normalized.split(separator: " ").map { String($0) })
        
        // Fetch all exercises
        let descriptor = FetchDescriptor<Exercise>()
        var exercises = (try? modelContext.fetch(descriptor)) ?? []
        
        if !includeHidden {
            exercises = exercises.filter { !$0.isHidden }
        }
        
        // Check for exact match first
        if let exactMatch = exercises.first(where: { normalize($0.name) == normalized }) {
            return ExerciseMatchResult(
                exercise: exactMatch,
                confidence: 1.0,
                isExactMatch: true,
                normalizedInput: normalized
            )
        }
        
        // Fuzzy match against all exercises
        var bestMatch: Exercise?
        var bestScore: Double = 0
        
        for exercise in exercises {
            let exerciseNormalized = normalize(exercise.name)
            let score = similarity(normalized, exerciseNormalized)
            
            // For fuzzy matches, also check word overlap to prevent wrong matches
            // e.g., "barbell squats" should NOT match "bicep curls"
            if score < 0.95 && score > 0 {
                let exerciseWords = Set(exerciseNormalized.split(separator: " ").map { String($0) })
                let sharedWords = inputWords.intersection(exerciseWords)
                
                // Require at least one shared word for lower-confidence matches
                if sharedWords.isEmpty {
                    continue // Skip this match - no words in common
                }
            }
            
            if score > bestScore {
                bestScore = score
                bestMatch = exercise
            }
        }
        
        return ExerciseMatchResult(
            exercise: bestMatch,
            confidence: bestScore,
            isExactMatch: false,
            normalizedInput: normalized
        )
    }
    
    /// Get all exercises sorted by name
    func getAllExercises() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { !$0.isHidden },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Search exercises by name with fuzzy matching
    /// Returns matches sorted by confidence score (highest first)
    func searchExercises(query: String) -> [(exercise: Exercise, confidence: Double)] {
        guard !query.isEmpty else { return [] }
        
        // Filter hidden in getAllExercises
        let allExercises = getAllExercises() 
        let normalizedQuery = normalize(query)
        
        var results: [(exercise: Exercise, confidence: Double)] = []
        
        for exercise in allExercises {
            let score = similarity(normalizedQuery, normalize(exercise.name))
            if score >= 0.3 { // Lower threshold for search suggestions
                results.append((exercise: exercise, confidence: score))
            }
        }
        
        return results.sorted { $0.confidence > $1.confidence }
    }
    
    /// Get all exercises matching a muscle group
    func exercises(forMuscleGroup muscleGroup: String) -> [Exercise] {
        let normalized = muscleGroup.lowercased()
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { exercise in
                exercise.muscleGroup.localizedStandardContains(normalized)
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - String Normalization
    
    /// Normalize a string for comparison (lowercase, remove punctuation, trim)
    private func normalize(_ input: String) -> String {
        input
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    /// Normalize for storage (title case, clean)
    private func normalizeForStorage(_ input: String) -> String {
        let words = input
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        return words.map { word in
            word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }
    
    // MARK: - Fuzzy Matching (Levenshtein Distance)
    
    /// Calculate similarity between two strings (0.0 to 1.0)
    private func similarity(_ s1: String, _ s2: String) -> Double {
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        guard maxLength > 0 else { return 1.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculate the Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        // Edge cases
        if m == 0 { return n }
        if n == 0 { return m }
        
        // Create distance matrix
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        // Initialize first column
        for i in 0...m {
            matrix[i][0] = i
        }
        
        // Initialize first row
        for j in 0...n {
            matrix[0][j] = j
        }
        
        // Fill in the rest
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}

