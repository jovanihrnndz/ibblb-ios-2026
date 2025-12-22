import Foundation
import AVKit
import Combine

/// Centralized audio playback controller for coordinating audio playback across the app.
/// Ensures only one audio source plays at a time and allows external control (e.g., pause when video opens).
@MainActor
class AudioPlaybackController: ObservableObject {
    static let shared = AudioPlaybackController()
    
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var isScrubbing = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var currentURL: URL?
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to set up AVAudioSession: \(error)")
        }
    }
    
    /// Loads and plays audio from the given URL.
    /// If the same URL is already playing, this is a no-op (idempotent).
    /// If the same URL is paused, it will resume playback.
    /// If a different URL is provided, it will replace the current playback.
    func play(url: URL) {
        // If already playing the same URL, do nothing (idempotent)
        if currentURL == url && isPlaying {
            return
        }
        
        // If same URL but paused, resume playback
        if currentURL == url && !isPlaying, let existingPlayer = player {
            existingPlayer.play()
            isPlaying = true
            return
        }
        
        // If URL is different, stop existing playback and start new
        if currentURL != url {
            stop()
        }
        
        // Ensure session is active before creating the player
        setupAudioSession()
        
        // Create new player item and player
        let newPlayerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: newPlayerItem)
        
        self.playerItem = newPlayerItem
        self.player = newPlayer
        self.currentURL = url
        
        // Observe duration
        newPlayerItem.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newDuration in
                let seconds = newDuration.seconds
                if seconds.isFinite && seconds > 0 {
                    self?.duration = seconds
                }
            }
            .store(in: &cancellables)
            
        // Observe status for loading errors
        newPlayerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed {
                    if let error = self?.playerItem?.error {
                        print("❌ Audio Playback Error: \(error.localizedDescription)")
                        print("🔗 Attempted URL: \(url.absoluteString)")
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe playback status
        newPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing)
            }
            .store(in: &cancellables)
        
        // Observe current time
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            // Only update currentTime from observer if we are not scrubbing
            MainActor.assumeIsolated {
                if !self.isScrubbing {
                    self.currentTime = seconds
                }
            }
        }
        
        // Start playing
        newPlayer.play()
        isPlaying = true
    }
    
    /// Pauses the current audio playback.
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    /// Stops and clears the current audio playback.
    func stop() {
        // Remove time observer before clearing player reference
        if let observer = timeObserver, let currentPlayer = player {
            currentPlayer.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        player?.pause()
        player = nil
        playerItem = nil
        currentURL = nil
        
        cancellables.removeAll()
        isPlaying = false
        currentTime = 0
        duration = 0
    }
    
    /// Seeks to the specified time in seconds.
    func seek(to time: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // Immediately update currentTime to prevent UI "flicker" returning to old time
        self.currentTime = time
        
        // Use zero tolerance for high-precision seeking
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    /// Skips forward or backward by the specified number of seconds.
    func skip(by seconds: Double) {
        guard player != nil else { return }
        let currentSeconds = currentTime
        let newTime = max(0, min(currentSeconds + seconds, duration))
        seek(to: newTime)
    }
}

