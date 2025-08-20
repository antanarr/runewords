import Foundation
import FirebaseAuth

/// Service for managing anonymous authentication
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published private(set) var uid: String?
    @Published private(set) var userId: String?
    @Published private(set) var isAuthenticated: Bool = false
    
    private init() {}
    
    /// Ensure user is signed in anonymously
    func ensureSignedIn() async {
        // Check if already signed in
        if let user = Auth.auth().currentUser {
            self.uid = user.uid
            self.userId = user.uid
            self.isAuthenticated = true
            print("✅ Auth: Already signed in as \(user.uid)")
            return
        }
        
        // Sign in anonymously
        do {
            let result = try await Auth.auth().signInAnonymously()
            self.uid = result.user.uid
            self.userId = result.user.uid
            self.isAuthenticated = true
            print("✅ Auth: Signed in anonymously as \(result.user.uid)")
        } catch {
            print("❌ Auth failed: \(error)")
            #if DEBUG
            assertionFailure("Auth failed: \(error)")
            #endif
        }
    }
    
    /// Sign out (for testing/debug)
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.uid = nil
            self.userId = nil
            self.isAuthenticated = false
            print("✅ Auth: Signed out")
        } catch {
            print("❌ Sign out failed: \(error)")
        }
    }
}
