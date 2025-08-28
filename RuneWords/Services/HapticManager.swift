import UIKit
import SwiftUI

/// Manages haptic feedback for the game
@MainActor
class HapticManager {
    static let shared = HapticManager()
    
    private var impactLight: UIImpactFeedbackGenerator?
    private var impactMedium: UIImpactFeedbackGenerator?
    private var impactHeavy: UIImpactFeedbackGenerator?
    private var notificationFeedback: UINotificationFeedbackGenerator?
    private var selectionFeedback: UISelectionFeedbackGenerator?
    
    // Check if haptics are available and enabled
    private var hapticsEnabled: Bool {
        // Check system settings and device capability
        return UIDevice.current.userInterfaceIdiom == .phone && 
               !UIAccessibility.isReduceMotionEnabled
    }
    
    private init() {
        setupGenerators()
    }
    
    private func setupGenerators() {
        guard hapticsEnabled else { return }
        
        impactLight = UIImpactFeedbackGenerator(style: .light)
        impactMedium = UIImpactFeedbackGenerator(style: .medium)
        impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        notificationFeedback = UINotificationFeedbackGenerator()
        selectionFeedback = UISelectionFeedbackGenerator()
        
        // Prepare generators for lower latency
        impactLight?.prepare()
        impactMedium?.prepare()
        impactHeavy?.prepare()
        notificationFeedback?.prepare()
        selectionFeedback?.prepare()
    }
    
    // Single public enum to avoid ambiguity
    enum Style: Sendable {
        case light, medium, heavy
        case success, warning, error
        case selection
    }
    
    // Single public API method
    func play(_ style: HapticManager.Style) {
        guard hapticsEnabled else { return }
        
        switch style {
        case .light:
            impactLight?.impactOccurred()
            impactLight?.prepare() // Prepare for next use
            
        case .medium:
            impactMedium?.impactOccurred()
            impactMedium?.prepare()
            
        case .heavy:
            impactHeavy?.impactOccurred()
            impactHeavy?.prepare()
            
        case .success:
            notificationFeedback?.notificationOccurred(.success)
            notificationFeedback?.prepare()
            
        case .warning:
            notificationFeedback?.notificationOccurred(.warning)
            notificationFeedback?.prepare()
            
        case .error:
            notificationFeedback?.notificationOccurred(.error)
            notificationFeedback?.prepare()
            
        case .selection:
            selectionFeedback?.selectionChanged()
            selectionFeedback?.prepare()
        }
    }
    
    /// Convenience method for impact with intensity
    func impact(intensity: CGFloat) {
        guard hapticsEnabled else { return }
        
        if intensity < 0.33 {
            play(.light)
        } else if intensity < 0.66 {
            play(.medium)
        } else {
            play(.heavy)
        }
    }
    
    /// Play a pattern of haptics
    func playPattern(_ pattern: [HapticManager.Style], withDelay delay: TimeInterval = 0.1) {
        guard hapticsEnabled else { return }
        
        for (index, haptic) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (delay * Double(index))) { [weak self] in
                self?.play(haptic)
            }
        }
    }
    
    /// Prepare all generators (call when view appears)
    func prepareAll() {
        guard hapticsEnabled else { return }
        
        impactLight?.prepare()
        impactMedium?.prepare()
        impactHeavy?.prepare()
        notificationFeedback?.prepare()
        selectionFeedback?.prepare()
    }
    
    // MARK: - HapticServiceProtocol conformance
    func prepare() {
        prepareAll()
    }
}
