//
//  PlateMathTool.swift
//  Spot
//
//  Tool for converting gym slang to actual weight values.
//  Conforms to Foundation Models Tool protocol.
//

import Foundation
import FoundationModels

/// Tool for converting gym slang to actual weight values
@available(iOS 26.0, *)
struct CalculatePlateMathTool: Tool {
    // Required metadata
    var name: String = "calculate_plate_math"
    var description: String = "Converts gym plate slang into total weight in pounds. Use when the user mentions plates (e.g., '2 plates', '1 plate and a 25', '3 plates'). A 'plate' is 45 lbs per side, plus a 45 lb bar."
    
    // Required output type
    typealias Output = String
    
    // Arguments the AI extracts from user input
    @Generable
    struct Arguments {
        @Guide(description: "The gym slang to convert (e.g., '2 plates', '1 plate and a 25', '3 plates and a 10')")
        var inputString: String
    }
    
    // The logic that runs when AI calls this tool
    nonisolated func call(arguments: Arguments) async throws -> String {
        let result = PlateMathCalculator.calculate(from: arguments.inputString)
        return "\(result.totalWeight) lbs (\(result.breakdown))"
    }
}

// MARK: - Plate Math Calculator (Shared Logic)

enum PlateMathCalculator {
    /// Standard Olympic barbell weight
    static let barWeight: Double = 45.0
    
    /// A "plate" is 45 lbs
    static let plateWeight: Double = 45.0
    
    struct CalculationResult: Sendable {
        let totalWeight: Int
        let breakdown: String
    }
    
    /// Calculate total weight from gym slang
    nonisolated static func calculate(from input: String) -> CalculationResult {
        let lowercased = input.lowercased()
        
        var totalWeight: Double = barWeight
        var breakdown = "Bar: 45 lbs"
        
        // Extract number of plates
        let plates = extractPlates(from: lowercased)
        if plates > 0 {
            let platesWeight = Double(plates) * plateWeight * 2 // Both sides
            totalWeight += platesWeight
            breakdown += " + \(plates) plate\(plates == 1 ? "" : "s") (\(Int(platesWeight)) lbs)"
        }
        
        // Extract additional small weights
        let smallWeights = extractSmallWeights(from: lowercased)
        for weight in smallWeights {
            let bothSides = weight * 2
            totalWeight += bothSides
            breakdown += " + 2x\(Int(weight)) lbs"
        }
        
        // Check for just a number (direct weight)
        if plates == 0 && smallWeights.isEmpty {
            if let directWeight = extractDirectWeight(from: input) {
                return CalculationResult(totalWeight: directWeight, breakdown: "\(directWeight) lbs total")
            }
        }
        
        return CalculationResult(
            totalWeight: Int(totalWeight),
            breakdown: breakdown
        )
    }
    
    /// Extract number of 45lb plates from input
    nonisolated private static func extractPlates(from input: String) -> Int {
        // Patterns: "1 plate", "2 plates", "a plate"
        let patterns = [
            #"(\d+)\s*plates?"#,
            #"(one|a)\s*plate"#,
            #"(two)\s*plates?"#,
            #"(three)\s*plates?"#,
            #"(four)\s*plates?"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input)),
               let range = Range(match.range(at: 1), in: input) {
                
                let captured = String(input[range]).lowercased()
                
                switch captured {
                case "one", "a": return 1
                case "two": return 2
                case "three": return 3
                case "four": return 4
                default:
                    if let num = Int(captured) {
                        return num
                    }
                }
            }
        }
        
        return 0
    }
    
    /// Extract smaller plate weights (25, 10, 5, 2.5)
    nonisolated private static func extractSmallWeights(from input: String) -> [Double] {
        var weights: [Double] = []
        
        // Look for "and a [number]" pattern
        let andPattern = #"and\s+(?:a\s+)?(\d+(?:\.\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: andPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: input, options: [], range: NSRange(input.startIndex..., in: input))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: input),
                   let weight = Double(input[range]) {
                    weights.append(weight)
                }
            }
        }
        
        return weights
    }
    
    /// Extract a direct weight number (e.g., "185" or "225 lbs")
    nonisolated private static func extractDirectWeight(from input: String) -> Int? {
        let pattern = #"^(\d+)\s*(?:lbs?|pounds?)?\s*$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: input, options: [], range: NSRange(input.startIndex..., in: input)),
              let range = Range(match.range(at: 1), in: input),
              let weight = Int(input[range]) else {
            return nil
        }
        
        return weight
    }
}
