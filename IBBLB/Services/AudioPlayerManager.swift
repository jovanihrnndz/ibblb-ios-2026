import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// Metadata for the currently playing audio track
struct AudioTrackInfo: Equatable {
    let title: String
    let artworkURL: URL?
    let audioURL: URL
}

/// Global audio player manager that persists across all views.
/// Provides playback state, progress updates, and metadata for the mini player.
@MainActor
final class AudioPlayerManager: ObservableObject {

    // MARK: - Singleton

    static let shared = AudioPlayerManager()

    // MARK: - Published Properties

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTrack: AudioTrackInfo?
    @Published var isScrubbing = false

    /// Whether the mini player should be visible
    var showMiniPlayer: Bool {
        currentTrack != nil
    }

    /// Progress as a value from 0 to 1
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var cachedArtwork: MPMediaItemArtwork?

    // MARK: - Initialization

    private init() {
        // NOTE: Do NOT call configureAudioSession() here.
        // Audio session activation interrupts external audio (Spotify, etc).
        // Session is activated lazily in play() when user initiates playback.
        setupRemoteCommandCenter()
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioPlayerManager: Failed to configure audio session - \(error.localizedDescription)")
        }
    }

    // MARK: - Remote Command Center (Lock Screen Controls)

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipForward()
            }
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipBackward()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let track = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let artwork = cachedArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func loadArtwork(from url: URL) {
        Task.detached(priority: .userInitiated) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }

                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

                await MainActor.run {
                    self.cachedArtwork = artwork
                    self.updateNowPlayingInfo()
                }
            } catch {
                print("AudioPlayerManager: Failed to load artwork - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Playback Control

    /// Starts playing audio with the given metadata
    /// - Parameters:
    ///   - url: The audio URL to play
    ///   - title: Track title for display
    ///   - artworkURL: Optional artwork URL for thumbnail
    func play(url: URL, title: String, artworkURL: URL?) {
        let newTrack = AudioTrackInfo(title: title, artworkURL: artworkURL, audioURL: url)

        // If same track, just toggle play/pause
        if let current = currentTrack, current.audioURL == url {
            if isPlaying {
                pause()
            } else {
                resume()
            }
            return
        }

        // Stop current playback
        stopInternal(clearTrack: false)

        // Clear cached artwork for new track
        cachedArtwork = nil

        // Load artwork if available
        if let artworkURL = artworkURL {
            loadArtwork(from: artworkURL)
        }

        // Ensure audio session is active
        configureAudioSession()

        // Create player
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)

        self.playerItem = item
        self.player = newPlayer
        self.currentTrack = newTrack

        // Observe duration
        item.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cmDuration in
                let seconds = cmDuration.seconds
                if seconds.isFinite && seconds > 0 {
                    self?.duration = seconds
                    self?.updateNowPlayingInfo()
                }
            }
            .store(in: &cancellables)

        // Observe status for errors
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed, let error = self?.playerItem?.error {
                    print("AudioPlayerManager: Playback error - \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)

        // Observe playback status
        newPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing)
                self?.updateNowPlayingInfo()
            }
            .store(in: &cancellables)

        // Add periodic time observer (~0.5s)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            MainActor.assumeIsolated {
                if !self.isScrubbing {
                    self.currentTime = seconds
                    self.updateNowPlayingInfo()
                }
            }
        }

        // Start playback
        newPlayer.play()
    }

    /// Resumes playback of the current track
    func resume() {
        player?.play()
    }

    /// Pauses playback
    func pause() {
        player?.pause()
    }

    /// Toggles between play and pause
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Stops playback and clears the current track (hides mini player)
    func stop() {
        stopInternal(clearTrack: true)
    }

    private func stopInternal(clearTrack: Bool) {
        // Remove time observer
        if let observer = timeObserver, let currentPlayer = player {
            currentPlayer.removeTimeObserver(observer)
            timeObserver = nil
        }

        player?.pause()
        player = nil
        playerItem = nil

        cancellables.removeAll()

        isPlaying = false
        currentTime = 0
        duration = 0

        if clearTrack {
            currentTrack = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

            // Deactivate audio session so other apps (Spotify, etc.) can resume
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("AudioPlayerManager: Failed to deactivate audio session - \(error.localizedDescription)")
            }
        }
    }

    /// Seeks to the specified time
    func seek(to time: TimeInterval) {
        guard let player else { return }

        let clampedTime = max(0, min(time, duration))
        self.currentTime = clampedTime

        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }

    /// Skips backward 15 seconds
    func skipBackward() {
        seek(to: currentTime - 15)
    }

    /// Skips forward 30 seconds
    func skipForward() {
        seek(to: currentTime + 30)
    }

    // MARK: - Time Formatting

    /// Formats seconds into "m:ss" or "h:mm:ss" string
    static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
