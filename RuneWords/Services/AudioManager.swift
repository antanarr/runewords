import AVFoundation
import SwiftUI

/// Manages all audio playback for the game
@MainActor
class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var isMusicEnabled: Bool = UserDefaults.standard.bool(forKey: "isMusicEnabled") {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "isMusicEnabled")
            if isMusicEnabled {
                playBackgroundMusic()
            } else {
                stopBackgroundMusic()
            }
        }
    }
    
    @Published var isSfxEnabled: Bool = UserDefaults.standard.bool(forKey: "isSfxEnabled") {
        didSet {
            UserDefaults.standard.set(isSfxEnabled, forKey: "isSfxEnabled")
        }
    }
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var backgroundMusicPlayer: AVAudioPlayer?
    
    // Sound effect types
    enum SoundEffect: String {
        case selectLetter = "sfx_select_letter"
        case success = "sfx_success_word"
        case fail = "sfx_fail_word"
        case bonus = "sfx_bonus_word"
        case levelComplete = "sfx_level_complete"
        case shuffle = "sfx_shuffle_letters"
        case uiClick = "sfx_ui_click"
        
        var fileExtension: String { "wav" }
    }
    
    private init() {
        setupAudioSession()
        preloadSounds()
        
        // Set initial states from UserDefaults
        if !UserDefaults.standard.exists(forKey: "isMusicEnabled") {
            UserDefaults.standard.set(true, forKey: "isMusicEnabled")
            isMusicEnabled = true
        }
        if !UserDefaults.standard.exists(forKey: "isSfxEnabled") {
            UserDefaults.standard.set(true, forKey: "isSfxEnabled")
            isSfxEnabled = true
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func preloadSounds() {
        // Preload all sound effects
        for effect in [SoundEffect.selectLetter, .success, .fail, .bonus, .levelComplete, .shuffle, .uiClick] {
            if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: effect.fileExtension) {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    audioPlayers[effect.rawValue] = player
                } catch {
                    print("Failed to load sound: \(effect.rawValue) - \(error)")
                    // Create a silent placeholder to prevent crashes
                    createSilentPlayer(for: effect.rawValue)
                }
            } else {
                print("Sound file not found: \(effect.rawValue).\(effect.fileExtension)")
                // Create a silent placeholder to prevent crashes
                createSilentPlayer(for: effect.rawValue)
            }
        }
    }
    
    private func createSilentPlayer(for key: String) {
        // Create a silent audio player as placeholder
        // This prevents crashes when audio files are missing
        let silence = Data(repeating: 0, count: 44100) // 1 second of silence
        if let player = try? AVAudioPlayer(data: silence, fileTypeHint: AVFileType.wav.rawValue) {
            player.prepareToPlay()
            audioPlayers[key] = player
        }
    }
    
    func playSound(effect: SoundEffect) {
        guard isSfxEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            if let player = self?.audioPlayers[effect.rawValue] {
                player.currentTime = 0
                player.play()
            } else {
                print("No player for sound: \(effect.rawValue)")
            }
        }
    }
    
    func playBackgroundMusic() {
        guard isMusicEnabled else { return }
        
        // For now, we'll skip background music if file doesn't exist
        guard let url = Bundle.main.url(forResource: "background_music", withExtension: "mp3") else {
            print("Background music file not found")
            return
        }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.numberOfLoops = -1 // Loop indefinitely
            backgroundMusicPlayer?.volume = 0.3
            backgroundMusicPlayer?.play()
        } catch {
            print("Failed to play background music: \(error)")
        }
    }
    
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
    }
    
    // MARK: - AudioServiceProtocol conformance
    func play(_ sound: SoundEffect) {
        playSound(effect: sound)
    }
    
    func setEffectsEnabled(_ enabled: Bool) {
        isSfxEnabled = enabled
    }
    
    func setMusicEnabled(_ enabled: Bool) {
        isMusicEnabled = enabled
    }
    
    func toggleMusic() {
        isMusicEnabled.toggle()
    }
    
    func toggleSfx() {
        isSfxEnabled.toggle()
    }
}

// Helper extension for UserDefaults
extension UserDefaults {
    func exists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
