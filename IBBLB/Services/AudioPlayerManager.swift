import Foundation
#if canImport(Combine)
import Combine
#endif

// MARK: - Shared Types (no platform dependencies)

/// Metadata for the currently playing audio track
struct AudioTrackInfo: Equatable {
    let title: String
    let artworkURL: URL?
    let audioURL: URL
}

/// Saved playback info for resume listening feature
/// Includes metadata for offline display when sermon list is unavailable
struct SavedPlaybackInfo: Equatable {
    let audioURL: String
    let time: TimeInterval
    let title: String?
    let thumbnailURL: String?

    /// Whether this is a legacy payload (pre-title/thumbnail)
    var isLegacy: Bool {
        title == nil && thumbnailURL == nil
    }
}

// MARK: - iOS Implementation

#if canImport(AVFoundation)
import AVFoundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
#endif

/// Simple reference wrapper for mutable values in closures
private final class Box<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
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
    @Published private(set) var isVideoPlaying: Bool = false

    func setVideoPlaying(_ playing: Bool) {
        isVideoPlaying = playing
    }

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
    private var lastSaveTime: TimeInterval = 0
    private var hasClearedOnFinish = false

    // MARK: - UserDefaults Keys

    private enum UserDefaultsKeys {
        static let lastPlayedAudioURL = "AudioPlayerManager.lastPlayedAudioURL"
        static let lastPlaybackTime = "AudioPlayerManager.lastPlaybackTime"
        // New keys for extended payload (added for offline resilience)
        static let lastPlayedTitle = "AudioPlayerManager.lastPlayedTitle"
        static let lastPlayedThumbnailURL = "AudioPlayerManager.lastPlayedThumbnailURL"
    }

    // MARK: - Resume Listening Access

    /// Returns the saved playback info if available
    /// Backward compatible: returns nil for title/thumbnailURL if saved with old format
    func getSavedPlaybackInfo() -> SavedPlaybackInfo? {
        guard let savedURLString = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastPlayedAudioURL),
              !savedURLString.isEmpty else {
            return nil
        }

        let savedTime = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastPlaybackTime)
        guard savedTime > 0 && savedTime.isFinite else {
            return nil
        }

        // Load extended metadata (may be nil for legacy payloads)
        let savedTitle = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastPlayedTitle)
        let savedThumbnailURL = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastPlayedThumbnailURL)

        return SavedPlaybackInfo(
            audioURL: savedURLString,
            time: savedTime,
            title: savedTitle,
            thumbnailURL: savedThumbnailURL
        )
    }

    /// Finds the sermon that matches the saved playback URL from the provided list
    /// - Parameter sermons: Array of sermons to search through
    /// - Returns: The matching sermon, or nil if not found
    func findContinueListeningSermon(from sermons: [Sermon]) -> Sermon? {
        guard let savedInfo = getSavedPlaybackInfo() else { return nil }
        let savedURLString = savedInfo.audioURL.trimmingCharacters(in: .whitespaces)
        guard !savedURLString.isEmpty else { return nil }

        return sermons.first { sermon in
            guard let audioUrlString = sermon.audioUrl else { return false }
            let trimmedAudioUrl = audioUrlString.trimmingCharacters(in: .whitespaces)
            guard !trimmedAudioUrl.isEmpty else { return false }

            // Direct string comparison (most reliable)
            if trimmedAudioUrl == savedURLString {
                return true
            }

            // URL-based comparison (handles encoding differences)
            guard let savedURL = URL(string: savedURLString),
                  let sermonURL = URL(string: trimmedAudioUrl) else {
                return false
            }

            return sermonURL.absoluteString == savedURL.absoluteString
        }
    }

    /// Continue listening result that can use saved metadata as fallback
    struct ContinueListeningResult: Equatable {
        let sermon: Sermon?
        let savedTime: TimeInterval
        let savedInfo: SavedPlaybackInfo

        /// Title to display - prefer sermon title, fall back to saved title
        var displayTitle: String {
            sermon?.title ?? savedInfo.title ?? "Unknown"
        }

        /// Thumbnail URL to display - prefer sermon, fall back to saved
        var displayThumbnailURL: String? {
            sermon?.thumbnailUrl ?? savedInfo.thumbnailURL
        }

        /// Whether we have a matching sermon from the list
        var hasMatchingSermon: Bool {
            sermon != nil
        }
    }

    /// Returns continue listening info with offline fallback
    /// - Parameter sermons: Array of sermons to search through
    /// - Returns: ContinueListeningResult with sermon (if found) and saved metadata, or nil if no saved playback
    func getContinueListeningInfo(from sermons: [Sermon]) -> ContinueListeningResult? {
        guard let savedInfo = getSavedPlaybackInfo() else { return nil }
        let sermon = findContinueListeningSermon(from: sermons)

        return ContinueListeningResult(
            sermon: sermon,
            savedTime: savedInfo.time,
            savedInfo: savedInfo
        )
    }

    /// Resumes listening for the given sermon from saved position
    /// - Parameter sermon: The sermon to resume playing
    func resumeListening(sermon: Sermon) {
        guard let audioUrlString = sermon.audioUrl,
              let audioURL = URL(string: audioUrlString.trimmingCharacters(in: .whitespaces)) else {
            return
        }

        // Construct artwork URL
        let artworkURL: URL? = buildArtworkURL(
            thumbnailUrl: sermon.thumbnailUrl,
            youtubeVideoId: sermon.youtubeVideoId
        )

        // Play audio (will auto-resume from saved position)
        play(url: audioURL, title: sermon.title, artworkURL: artworkURL)
    }

    /// Resumes listening from continue listening result (supports offline fallback)
    /// - Parameter result: The continue listening result containing sermon or saved info
    func resumeListening(from result: ContinueListeningResult) {
        // Prefer sermon if available
        if let sermon = result.sermon {
            resumeListening(sermon: sermon)
            return
        }

        // Fallback to saved info for offline case
        guard let audioURL = URL(string: result.savedInfo.audioURL) else { return }

        let artworkURL: URL? = {
            if let thumbnailString = result.savedInfo.thumbnailURL,
               !thumbnailString.isEmpty {
                return URL(string: thumbnailString)
            }
            return nil
        }()

        play(url: audioURL, title: result.displayTitle, artworkURL: artworkURL)
    }

    /// Helper to build artwork URL from sermon metadata
    private func buildArtworkURL(thumbnailUrl: String?, youtubeVideoId: String?) -> URL? {
        var videoId: String?

        if let thumbnailString = thumbnailUrl,
           !thumbnailString.isEmpty {
            videoId = YouTubeThumbnail.videoId(from: thumbnailString)
        }

        if videoId == nil,
           let youtubeId = youtubeVideoId,
           !youtubeId.trimmingCharacters(in: .whitespaces).isEmpty {
            videoId = YouTubeVideoIDExtractor.extractVideoID(from: youtubeId)
        }

        if let id = videoId {
            return YouTubeThumbnail.url(videoId: id, quality: .maxres)
        }

        if let thumbnailString = thumbnailUrl,
           !thumbnailString.isEmpty,
           let url = URL(string: thumbnailString),
           !YouTubeThumbnail.isYouTubeThumbnail(url) {
            return url
        }

        return nil
    }

    // MARK: - Initialization

    private init() {
        // NOTE: Do NOT call configureAudioSession() here.
        // Audio session activation interrupts external audio (Spotify, etc).
        // Session is activated lazily in play() when user initiates playback.
        setupRemoteCommandCenter()
        setupBackgroundNotifications()
    }

    // MARK: - Resume Listening Persistence

    private func savePlaybackPosition() {
        guard let track = currentTrack else { return }

        // Save core playback info
        UserDefaults.standard.set(track.audioURL.absoluteString, forKey: UserDefaultsKeys.lastPlayedAudioURL)
        UserDefaults.standard.set(currentTime, forKey: UserDefaultsKeys.lastPlaybackTime)

        // Save extended metadata for offline resilience
        UserDefaults.standard.set(track.title, forKey: UserDefaultsKeys.lastPlayedTitle)
        if let artworkURL = track.artworkURL {
            UserDefaults.standard.set(artworkURL.absoluteString, forKey: UserDefaultsKeys.lastPlayedThumbnailURL)
        } else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastPlayedThumbnailURL)
        }
    }

    private func loadPlaybackPosition(for url: URL) -> TimeInterval? {
        guard let savedURLString = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastPlayedAudioURL),
              savedURLString == url.absoluteString else {
            return nil
        }

        let savedTime = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastPlaybackTime)
        guard savedTime > 0 && savedTime.isFinite else {
            return nil
        }

        return savedTime
    }

    private func clearPlaybackPosition() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastPlayedAudioURL)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastPlaybackTime)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastPlayedTitle)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastPlayedThumbnailURL)
    }

    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.savePlaybackPosition()
            }
        }
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

        // Check for saved playback position
        let savedPosition = loadPlaybackPosition(for: url)
        let hasRestoredPosition = Box(false)
        hasClearedOnFinish = false

        // Create player
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)

        self.playerItem = item
        self.player = newPlayer
        self.currentTrack = newTrack

        // Attempt immediate seek to saved position (works even if duration is unknown)
        if !hasRestoredPosition.value, let savedPos = savedPosition, savedPos >= 0 {
            seekToSavedPosition(savedPos)
            hasRestoredPosition.value = true
        }

        // Observe duration and restore position if needed (fallback if immediate seek didn't work)
        item.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cmDuration in
                guard let self else { return }
                let seconds = cmDuration.seconds
                if seconds.isFinite && seconds > 0 {
                    self.duration = seconds

                    // Restore saved position if available (only once, as fallback)
                    if !hasRestoredPosition.value, let savedPos = savedPosition, savedPos >= 0 {
                        self.seekToSavedPosition(savedPos)
                        hasRestoredPosition.value = true
                    }

                    self.updateNowPlayingInfo()
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
        let saveInterval: TimeInterval = 5.0 // Save every 5 seconds
        lastSaveTime = 0

        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            MainActor.assumeIsolated {
                if !self.isScrubbing {
                    self.currentTime = seconds
                    self.updateNowPlayingInfo()

                    // Clear position when playback is effectively finished (within 2s of end)
                    if !self.hasClearedOnFinish, self.duration > 0, seconds >= self.duration - 2.0 {
                        self.clearPlaybackPosition()
                        self.hasClearedOnFinish = true
                    }

                    // Save position periodically (every 5 seconds)
                    if seconds - self.lastSaveTime >= saveInterval {
                        self.savePlaybackPosition()
                        self.lastSaveTime = seconds
                    }
                }
            }
        }

        // Observe end-of-track to clear saved position (fallback if time observer didn't catch it)
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.hasClearedOnFinish else { return }
                self.clearPlaybackPosition()
                self.hasClearedOnFinish = true
            }
            .store(in: &cancellables)

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
        savePlaybackPosition()
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
        hasClearedOnFinish = false

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
        guard let player, duration > 0 else { return }

        let clampedTime = max(0, min(time, duration))
        self.currentTime = clampedTime

        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }

    /// Internal seek that works even when duration is unknown
    private func seekToSavedPosition(_ time: TimeInterval) {
        guard let player else { return }
        guard time >= 0 && time.isFinite else { return }

        // Only clamp to duration if duration is known (> 0)
        let targetTime = duration > 0 ? max(0, min(time, duration)) : time
        self.currentTime = targetTime

        let cmTime = CMTime(seconds: targetTime, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlayingInfo()
    }

    /// Skips backward 15 seconds
    func skipBackward() {
        skip(by: -15)
    }

    /// Skips forward 30 seconds
    func skipForward() {
        skip(by: 30)
    }

    /// Skips forward or backward by the specified number of seconds
    /// - Parameter seconds: Positive value to skip forward, negative to skip backward
    func skip(by seconds: TimeInterval) {
        guard duration > 0 else { return }
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
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

// MARK: - Android Stub

#else

/// Android stub — ExoPlayer integration replaces this in a future phase.
/// Satisfies all callers at compile time; playback is a no-op until implemented.
@MainActor
final class AudioPlayerManager: ObservableObject {

    static let shared = AudioPlayerManager()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTrack: AudioTrackInfo?
    @Published var isScrubbing = false
    @Published private(set) var isVideoPlaying: Bool = false

    func setVideoPlaying(_ playing: Bool) { isVideoPlaying = playing }

    var showMiniPlayer: Bool { currentTrack != nil }
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    struct ContinueListeningResult: Equatable {
        let sermon: Sermon?
        let savedTime: TimeInterval
        let savedInfo: SavedPlaybackInfo

        var displayTitle: String { sermon?.title ?? savedInfo.title ?? "Unknown" }
        var displayThumbnailURL: String? { sermon?.thumbnailUrl ?? savedInfo.thumbnailURL }
        var hasMatchingSermon: Bool { sermon != nil }
    }

    private init() {}

    func getSavedPlaybackInfo() -> SavedPlaybackInfo? { nil }
    func findContinueListeningSermon(from sermons: [Sermon]) -> Sermon? { nil }
    func getContinueListeningInfo(from sermons: [Sermon]) -> ContinueListeningResult? { nil }
    func resumeListening(sermon: Sermon) {}
    func resumeListening(from result: ContinueListeningResult) {}
    func play(url: URL, title: String, artworkURL: URL?) {}
    func resume() {}
    func pause() {}
    func togglePlayPause() {}
    func stop() {}
    func seek(to time: TimeInterval) {}
    func skipBackward() {}
    func skipForward() {}
    func skip(by seconds: TimeInterval) {}

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

#endif
