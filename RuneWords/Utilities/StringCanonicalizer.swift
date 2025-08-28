// StringCanonicalizer.swift
// Single source of truth for string canonicalization across the app

import Foundation

/// Single source of truth for string canonicalization across the app
struct StringCanonicalizer {
    /// Canonicalize a word for consistent comparison and storage
    /// - Uppercase
    /// - Remove diacritics
    /// - Trim whitespace
    static func canon(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
    }
    
    /// Canonicalize level ID to consistent string format
    static func levelKey(_ levelID: Int) -> String {
        String(levelID)
    }
}
