import Foundation
import FirebaseFirestore

/// Service for managing player progress in Firestore
@MainActor
final class ProgressService: ObservableObject {
    static let shared = ProgressService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Player Document Management
    
    /// Ensure player document exists in Firestore
    /// players/{uid}
    func ensurePlayerDoc(uid: String) async {
        let ref = db.collection("players").document(uid)
        
        do {
            let snap = try await ref.getDocument()
            if snap.exists {
                print("✅ Progress: Player doc exists for \(uid)")
                return
            }
            
            // Create new player document with proper defaults
            let username = "Seeker-\(Int.random(in: 1000...9999))"
            try await ref.setData([
                "username": username,
                "createdAt": FieldValue.serverTimestamp(),
                "lastSeenAt": FieldValue.serverTimestamp(),
                "currentLevelID": 1,  // Default to level 1 instead of delete
                "coins": 50,  // Starting coins
                "totalLevelsCompleted": 0,
                "totalHintsUsed": 0,
                "totalBonusWords": 0,
                "levelProgress": [:],
                "foundBonusWords": [],
                "preferredDifficulty": "easy"
            ])
            print("✅ Progress: Created player doc for \(uid) as \(username)")
        } catch {
            print("❌ Progress: Failed to ensure player doc: \(error)")
        }
    }
    
    /// Update last seen timestamp
    func touchLastSeen(uid: String) async {
        let ref = db.collection("players").document(uid)
        do {
            try await ref.updateData(["lastSeenAt": FieldValue.serverTimestamp()])
            print("✅ Progress: Updated last seen for \(uid)")
        } catch {
            print("❌ Progress: Failed to update last seen: \(error)")
        }
    }
    
    // MARK: - Level Progress
    
    /// Mark a level as complete
    /// players/{uid}/progress/{levelId}
    func markLevelComplete(uid: String, levelId: Int, stats: [String: Any] = [:]) async {
        let playerRef = db.collection("players").document(uid)
        let progressRef = playerRef.collection("progress").document(String(levelId))
        
        do {
            // Update progress document
            try await progressRef.setData([
                "completed": true,
                "completedAt": FieldValue.serverTimestamp(),
                "levelId": levelId
            ].merging(stats, uniquingKeysWith: { _, new in new }))
            
            // Update player stats
            try await playerRef.updateData([
                "lastLevelId": levelId,
                "totalLevelsCompleted": FieldValue.increment(Int64(1))
            ])
            
            print("✅ Progress: Marked level \(levelId) complete for \(uid)")
        } catch {
            print("❌ Progress: Failed to mark level complete: \(error)")
        }
    }
    
    /// Fetch the last completed level ID
    func fetchLastLevelId(uid: String) async -> Int? {
        let ref = db.collection("players").document(uid)
        
        do {
            let snap = try await ref.getDocument()
            let lastLevel = snap.data()?["lastLevelId"] as? Int
            print("✅ Progress: Last level for \(uid): \(lastLevel ?? 0)")
            return lastLevel
        } catch {
            print("❌ Progress: Failed to fetch last level: \(error)")
            return nil
        }
    }
    
    /// Check if a level has been completed
    func hasCompleted(uid: String, levelId: Int) async -> Bool {
        let ref = db.collection("players").document(uid)
            .collection("progress").document(String(levelId))
        
        do {
            let exists = try await ref.getDocument().exists
            print("✅ Progress: Level \(levelId) completed: \(exists)")
            return exists
        } catch {
            print("❌ Progress: Failed to check completion: \(error)")
            return false
        }
    }
    
    // MARK: - Player Stats
    
    /// Update player coins
    func updateCoins(uid: String, amount: Int) async {
        let ref = db.collection("players").document(uid)
        
        do {
            try await ref.updateData([
                "coins": FieldValue.increment(Int64(amount))
            ])
            print("✅ Progress: Updated coins by \(amount) for \(uid)")
        } catch {
            print("❌ Progress: Failed to update coins: \(error)")
        }
    }
    
    /// Increment hints used counter
    func incrementHintsUsed(uid: String) async {
        let ref = db.collection("players").document(uid)
        
        do {
            try await ref.updateData([
                "totalHintsUsed": FieldValue.increment(Int64(1))
            ])
            print("✅ Progress: Incremented hints used for \(uid)")
        } catch {
            print("❌ Progress: Failed to increment hints: \(error)")
        }
    }
    
    /// Fetch player stats
    func fetchPlayerStats(uid: String) async -> [String: Any]? {
        let ref = db.collection("players").document(uid)
        
        do {
            let snap = try await ref.getDocument()
            return snap.data()
        } catch {
            print("❌ Progress: Failed to fetch player stats: \(error)")
            return nil
        }
    }
    
    // MARK: - Batch Operations
    
    /// Fetch all completed level IDs for a player
    func fetchCompletedLevelIds(uid: String) async -> Set<Int> {
        let ref = db.collection("players").document(uid).collection("progress")
        
        do {
            let snap = try await ref.getDocuments()
            let levelIds = snap.documents.compactMap { doc -> Int? in
                guard let completed = doc.data()["completed"] as? Bool, completed else { return nil }
                return Int(doc.documentID)
            }
            print("✅ Progress: Found \(levelIds.count) completed levels for \(uid)")
            return Set(levelIds)
        } catch {
            print("❌ Progress: Failed to fetch completed levels: \(error)")
            return []
        }
    }
}
