//
//  PlateMathCalculator.swift
//  Spot
//
//  Utility for converting gym plate slang (e.g., "2 plates") to total weight.
//

import Foundation

/// Result of plate math calculation
struct PlateMathResult {
    let totalWeight: Int
    let breakdown: String
}

/// Calculator for gym plate math slang
enum PlateMathCalculator {
    
    /// Standard plate weights in pounds
    private static let plateWeights: [(name: String, weight: Double)] = [
        ("45", 45),
        ("35", 35),
        ("25", 25),
        ("10", 10),
        ("5", 5),
        ("2.5", 2.5)
    ]
    
    /// Weight of a standard Olympic barbell
    private static let barbellWeight: Double = 45
    
    /// Calculate total weight from plate slang
    /// - Parameter input: The gym slang (e.g., "2 plates", "1 plate and a 25")
    /// - Returns: Total weight and breakdown description
    static func calculate(from input: String) -> PlateMathResult {
        let lowercased = input.lowercased()
        var total: Double = barbellWeight // Start with barbell
        var breakdown: [String] = ["45lb bar"]
        
        // Pattern: "X plates" = X * 45 per side = X * 90 total
        if let plateCount = extractPlateCount(from: lowercased) {
            let platesWeight = Double(plateCount) * 45 * 2 // per side * 2
            total += platesWeight
            breakdown.append("\(plateCount)x 45lb plates (each side)")
        }
        
        // Look for additional plates mentioned
        for (name, weight) in plateWeights {
            // Pattern: "and a 25", "plus 25s", "with 10s"
            let patterns = [
                "and a \(name)",
                "and \(name)",
                "plus \(name)",
                "with \(name)",
                "\(name)s",
                "\(name) lb",
                "\(name)lb"
            ]
            
            for pattern in patterns {
                if lowercased.contains(pattern) && !lowercased.contains("\(name) plate") {
                    total += weight * 2 // per side
                    breakdown.append("\(name)lb plates (each side)")
                    break
                }
            }
        }
        
        return PlateMathResult(
            totalWeight: Int(total),
            breakdown: breakdown.joined(separator: " + ")
        )
    }
    
    /// Extract the number of 45lb plates from input
    private static func extractPlateCount(from input: String) -> Int? {
        // Common patterns
        let patterns: [(String, Int)] = [
            ("1 plate", 1),
            ("one plate", 1),
            ("a plate", 1),
            ("2 plates", 2),
            ("two plates", 2),
            ("3 plates", 3),
            ("three plates", 3),
            ("4 plates", 4),
            ("four plates", 4),
            ("5 plates", 5),
            ("five plates", 5),
            ("6 plates", 6),
            ("six plates", 6)
        ]
        
        for (pattern, count) in patterns {
            if input.contains(pattern) {
                return count
            }
        }
        
        // Try to extract number + "plate(s)"
        let regex = try? NSRegularExpression(pattern: "(\\d+)\\s*plates?", options: [])
        if let match = regex?.firstMatch(
            in: input,
            options: [],
            range: NSRange(input.startIndex..., in: input)
        ) {
            if let range = Range(match.range(at: 1), in: input),
               let count = Int(input[range]) {
                return count
            }
        }
        
        return nil
    }
}
