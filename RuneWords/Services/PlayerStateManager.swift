import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class PlayerStateManager: ObservableObject {
    static let shared = PlayerStateManager()
    
    private var updateTimer: Timer?
    private var pendingUpdates: [String: Any] = [:]
    private let updateDebounceInterval: TimeInterval = 0.5
    
    private init() {}
    
    /// Queue an update to be batched
    func queueUpdate(field: String, value: Any) {
        pendingUpdates[field] = value
        scheduleUpdate()
    }
    
    /// Queue multiple updates
    func queueUpdates(_ updates: [String: Any]) {
        pendingUpdates.merge(updates) { _, new in new }
        scheduleUpdate()
    }
    
    private func scheduleUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateDebounceInterval, repeats: false) { _ in
            Task { @MainActor in
                self.flushUpdates()
            }
        }
    }
    
    private func flushUpdates() {
        guard !pendingUpdates.isEmpty,
              let uid = AuthService.shared.uid else { return }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        // Send batched updates to Firestore
        let db = Firestore.firestore()
        let playerRef = db.collection("players").document(uid)
        
        playerRef.updateData(updates) { error in
            if let error = error {
                print("Error flushing updates: \(error)")
                // Re-queue failed updates
                self.pendingUpdates.merge(updates) { _, new in new }
            } else {
                print("✅ Flushed \(updates.count) updates to Firestore")
            }
        }
    }
    
    /// Force flush any pending updates
    func forcedFlush() {
        updateTimer?.invalidate()
        flushUpdates()
    }
}
