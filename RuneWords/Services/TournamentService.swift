//
//  TournamentService.swift
//  RuneWords
//
//  Tournament and competitive features system (stub)
//

import Foundation
import Combine
import SwiftUI

// MARK: - Stub Data Models
struct Tournament: Codable, Identifiable {
    let id: String
    let name: String
    let theme: String
    let startDate: Date
    let endDate: Date
    let entryFee: Int?
    var participantCount: Int = 0
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
}

struct TournamentEntry: Codable {
    let playerId: String
    let score: Int
    let completedAt: Date
}

// MARK: - Tournament Service (Stub)
@MainActor
class TournamentService: ObservableObject {
    static let shared = TournamentService()
    
    @Published var activeTournaments: [Tournament] = []
    @Published var userEntries: [TournamentEntry] = []
    @Published var isLoading = false
    
    private init() {
        // Stub implementation - no actual tournaments
    }
    
    func loadActiveTournaments() async {
        // Stub - no tournaments to load
        activeTournaments = []
    }
    
    func enterTournament(_ tournament: Tournament) async -> Bool {
        // Stub - always fail
        return false
    }
    
    func submitScore(_ score: Int, for tournament: Tournament) async -> Bool {
        // Stub - always fail
        return false
    }
}