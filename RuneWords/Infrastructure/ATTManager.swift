import Foundation
import AppTrackingTransparency
import AdSupport

@MainActor 
enum ATTManager {
    static func requestIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else { return }
        await withCheckedContinuation { cont in
            ATTrackingManager.requestTrackingAuthorization { _ in cont.resume() }
        }
    }
}
