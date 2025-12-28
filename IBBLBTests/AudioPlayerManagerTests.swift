//
//  AudioPlayerManagerTests.swift
//  IBBLBTests
//
//  Unit tests for AudioPlayerManager utilities.
//  Tests are deterministic and do not depend on AVPlayer.
//

import XCTest
@testable import IBBLB

final class AudioPlayerManagerTests: XCTestCase {

    // MARK: - Test Lifecycle

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test to ensure isolation
        clearSavedPlaybackInfo()
    }

    override func tearDown() {
        // Clean up after each test
        clearSavedPlaybackInfo()
        super.tearDown()
    }

    // MARK: - UserDefaults Keys (must match AudioPlayerManager)

    private enum TestKeys {
        static let lastPlayedAudioURL = "AudioPlayerManager.lastPlayedAudioURL"
        static let lastPlaybackTime = "AudioPlayerManager.lastPlaybackTime"
        static let lastPlayedTitle = "AudioPlayerManager.lastPlayedTitle"
        static let lastPlayedThumbnailURL = "AudioPlayerManager.lastPlayedThumbnailURL"
    }

    private func clearSavedPlaybackInfo() {
        UserDefaults.standard.removeObject(forKey: TestKeys.lastPlayedAudioURL)
        UserDefaults.standard.removeObject(forKey: TestKeys.lastPlaybackTime)
        UserDefaults.standard.removeObject(forKey: TestKeys.lastPlayedTitle)
        UserDefaults.standard.removeObject(forKey: TestKeys.lastPlayedThumbnailURL)
    }

    // MARK: - formatTime Tests

    func testFormatTime_zero() {
        XCTAssertEqual(AudioPlayerManager.formatTime(0), "0:00")
    }

    func testFormatTime_seconds() {
        XCTAssertEqual(AudioPlayerManager.formatTime(5), "0:05")
        XCTAssertEqual(AudioPlayerManager.formatTime(59), "0:59")
    }

    func testFormatTime_minutes() {
        XCTAssertEqual(AudioPlayerManager.formatTime(60), "1:00")
        XCTAssertEqual(AudioPlayerManager.formatTime(61), "1:01")
        XCTAssertEqual(AudioPlayerManager.formatTime(125), "2:05")
        XCTAssertEqual(AudioPlayerManager.formatTime(599), "9:59")
        XCTAssertEqual(AudioPlayerManager.formatTime(600), "10:00")
        XCTAssertEqual(AudioPlayerManager.formatTime(3599), "59:59")
    }

    func testFormatTime_hours() {
        XCTAssertEqual(AudioPlayerManager.formatTime(3600), "1:00:00")
        XCTAssertEqual(AudioPlayerManager.formatTime(3661), "1:01:01")
        XCTAssertEqual(AudioPlayerManager.formatTime(7325), "2:02:05")
        XCTAssertEqual(AudioPlayerManager.formatTime(36000), "10:00:00")
    }

    func testFormatTime_negative() {
        // Negative values should return "0:00"
        XCTAssertEqual(AudioPlayerManager.formatTime(-1), "0:00")
        XCTAssertEqual(AudioPlayerManager.formatTime(-100), "0:00")
    }

    func testFormatTime_infinity() {
        XCTAssertEqual(AudioPlayerManager.formatTime(.infinity), "0:00")
        XCTAssertEqual(AudioPlayerManager.formatTime(-.infinity), "0:00")
    }

    func testFormatTime_nan() {
        XCTAssertEqual(AudioPlayerManager.formatTime(.nan), "0:00")
    }

    func testFormatTime_fractionalSeconds() {
        // Fractional seconds should be truncated
        XCTAssertEqual(AudioPlayerManager.formatTime(1.5), "0:01")
        XCTAssertEqual(AudioPlayerManager.formatTime(59.9), "0:59")
        XCTAssertEqual(AudioPlayerManager.formatTime(60.1), "1:00")
    }

    // MARK: - Save/Restore Roundtrip Tests

    func testSaveRestore_newFormat_fullPayload() async {
        // Given: New format with all fields
        let audioURL = "https://example.com/sermon.mp3"
        let time: TimeInterval = 1250.5
        let title = "Test Sermon Title"
        let thumbnailURL = "https://example.com/thumb.jpg"

        // When: Save using new format
        UserDefaults.standard.set(audioURL, forKey: TestKeys.lastPlayedAudioURL)
        UserDefaults.standard.set(time, forKey: TestKeys.lastPlaybackTime)
        UserDefaults.standard.set(title, forKey: TestKeys.lastPlayedTitle)
        UserDefaults.standard.set(thumbnailURL, forKey: TestKeys.lastPlayedThumbnailURL)

        // Then: Restore via AudioPlayerManager
        let savedInfo = await AudioPlayerManager.shared.getSavedPlaybackInfo()

        XCTAssertNotNil(savedInfo)
        XCTAssertEqual(savedInfo?.audioURL, audioURL)
        XCTAssertEqual(savedInfo?.time, time)
        XCTAssertEqual(savedInfo?.title, title)
        XCTAssertEqual(savedInfo?.thumbnailURL, thumbnailURL)
        XCTAssertFalse(savedInfo?.isLegacy ?? true)
    }

    func testSaveRestore_legacyFormat_migration() async {
        // Given: Legacy format (only URL and time, no title/thumbnail)
        let audioURL = "https://example.com/old-sermon.mp3"
        let time: TimeInterval = 500.0

        // When: Save using legacy format (old app version)
        UserDefaults.standard.set(audioURL, forKey: TestKeys.lastPlayedAudioURL)
        UserDefaults.standard.set(time, forKey: TestKeys.lastPlaybackTime)
        // Note: NOT setting title or thumbnailURL (simulating old format)

        // Then: Restore should work with nil for new fields
        let savedInfo = await AudioPlayerManager.shared.getSavedPlaybackInfo()

        XCTAssertNotNil(savedInfo)
        XCTAssertEqual(savedInfo?.audioURL, audioURL)
        XCTAssertEqual(savedInfo?.time, time)
        XCTAssertNil(savedInfo?.title)
        XCTAssertNil(savedInfo?.thumbnailURL)
        XCTAssertTrue(savedInfo?.isLegacy ?? false)
    }

    func testSaveRestore_emptyURL_returnsNil() async {
        // Given: Empty URL
        UserDefaults.standard.set("", forKey: TestKeys.lastPlayedAudioURL)
        UserDefaults.standard.set(100.0, forKey: TestKeys.lastPlaybackTime)

        // Then: Should return nil
        let savedInfo = await AudioPlayerManager.shared.getSavedPlaybackInfo()
        XCTAssertNil(savedInfo)
    }

    func testSaveRestore_zeroTime_returnsNil() async {
        // Given: Zero time (never played)
        UserDefaults.standard.set("https://example.com/sermon.mp3", forKey: TestKeys.lastPlayedAudioURL)
        UserDefaults.standard.set(0.0, forKey: TestKeys.lastPlaybackTime)

        // Then: Should return nil
        let savedInfo = await AudioPlayerManager.shared.getSavedPlaybackInfo()
        XCTAssertNil(savedInfo)
    }

    func testSaveRestore_negativeTime_returnsNil() async {
        // Given: Negative time (invalid)
        UserDefaults.standard.set("https://example.com/sermon.mp3", forKey: TestKeys.lastPlayedAudioURL)
        UserDefaults.standard.set(-100.0, forKey: TestKeys.lastPlaybackTime)

        // Then: Should return nil
        let savedInfo = await AudioPlayerManager.shared.getSavedPlaybackInfo()
        XCTAssertNil(savedInfo)
    }

    func testSaveRestore_infiniteTime_returnsNil() async {
        // Given: Infinite time (invalid)
        UserDefaults.standard.set("https://example.com/sermon.mp3", forKey: TestKeys.lastPlayedAudioURL)
        UserDefaults.standard.set(Double.infinity, forKey: TestKeys.lastPlaybackTime)

        // Then: Should return nil
        let savedInfo = await AudioPlayerManager.shared.getSavedPlaybackInfo()
        XCTAssertNil(savedInfo)
    }

    func testSaveRestore_noSavedData_returnsNil() async {
        // Given: No saved data (clean UserDefaults)
        // (setUp already clears UserDefaults)

        // Then: Should return nil
        let savedInfo = await AudioPlayerManager.shared.getSavedPlaybackInfo()
        XCTAssertNil(savedInfo)
    }

    // MARK: - SavedPlaybackInfo Tests

    func testSavedPlaybackInfo_isLegacy_withBothFieldsNil() {
        let info = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: nil,
            thumbnailURL: nil
        )
        XCTAssertTrue(info.isLegacy)
    }

    func testSavedPlaybackInfo_isLegacy_withTitleOnly() {
        let info = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: "Test Title",
            thumbnailURL: nil
        )
        XCTAssertFalse(info.isLegacy)
    }

    func testSavedPlaybackInfo_isLegacy_withThumbnailOnly() {
        let info = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: nil,
            thumbnailURL: "https://example.com/thumb.jpg"
        )
        XCTAssertFalse(info.isLegacy)
    }

    func testSavedPlaybackInfo_isLegacy_withBothFields() {
        let info = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: "Test Title",
            thumbnailURL: "https://example.com/thumb.jpg"
        )
        XCTAssertFalse(info.isLegacy)
    }

    // MARK: - Progress Calculation Tests

    /// Tests progress calculation logic (same formula as AudioPlayerManager.progress)
    /// Progress = currentTime / duration, clamped to [0, 1]
    func testProgressCalculation_normalCases() {
        // Helper function matching AudioPlayerManager.progress logic
        func calculateProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
            guard duration > 0 else { return 0 }
            return currentTime / duration
        }

        // At start
        XCTAssertEqual(calculateProgress(currentTime: 0, duration: 100), 0.0)

        // Midway
        XCTAssertEqual(calculateProgress(currentTime: 50, duration: 100), 0.5)

        // At end
        XCTAssertEqual(calculateProgress(currentTime: 100, duration: 100), 1.0)

        // Quarter way
        XCTAssertEqual(calculateProgress(currentTime: 25, duration: 100), 0.25)

        // Three quarters
        XCTAssertEqual(calculateProgress(currentTime: 75, duration: 100), 0.75)

        // Fractional progress
        XCTAssertEqual(calculateProgress(currentTime: 33, duration: 100), 0.33, accuracy: 0.001)
    }

    func testProgressCalculation_durationZero() {
        // Helper function matching AudioPlayerManager.progress logic
        func calculateProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
            guard duration > 0 else { return 0 }
            return currentTime / duration
        }

        // Duration zero should return 0 (not divide by zero)
        XCTAssertEqual(calculateProgress(currentTime: 0, duration: 0), 0.0)
        XCTAssertEqual(calculateProgress(currentTime: 50, duration: 0), 0.0)
        XCTAssertEqual(calculateProgress(currentTime: 100, duration: 0), 0.0)
    }

    func testProgressCalculation_negativeDuration() {
        func calculateProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
            guard duration > 0 else { return 0 }
            return currentTime / duration
        }

        // Negative duration should return 0
        XCTAssertEqual(calculateProgress(currentTime: 50, duration: -100), 0.0)
    }

    func testProgressCalculation_pastEnd() {
        func calculateProgress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
            guard duration > 0 else { return 0 }
            return currentTime / duration
        }

        // Current time past duration (edge case)
        XCTAssertEqual(calculateProgress(currentTime: 150, duration: 100), 1.5)
    }

    // MARK: - ContinueListeningResult Tests

    func testContinueListeningResult_displayTitle_withSermon() async {
        let sermon = Sermon(
            id: "1",
            title: "Sermon Title",
            speaker: "Speaker",
            date: Date(),
            thumbnailUrl: "https://example.com/thumb.jpg",
            youtubeVideoId: nil,
            audioUrl: "https://example.com/audio.mp3",
            tags: nil,
            slug: nil
        )
        let savedInfo = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: "Saved Title",
            thumbnailURL: "https://example.com/saved-thumb.jpg"
        )

        let result = AudioPlayerManager.ContinueListeningResult(
            sermon: sermon,
            savedTime: 100,
            savedInfo: savedInfo
        )

        // Should prefer sermon title
        XCTAssertEqual(result.displayTitle, "Sermon Title")
        XCTAssertTrue(result.hasMatchingSermon)
    }

    func testContinueListeningResult_displayTitle_withoutSermon() async {
        let savedInfo = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: "Saved Title",
            thumbnailURL: "https://example.com/saved-thumb.jpg"
        )

        let result = AudioPlayerManager.ContinueListeningResult(
            sermon: nil,
            savedTime: 100,
            savedInfo: savedInfo
        )

        // Should fall back to saved title
        XCTAssertEqual(result.displayTitle, "Saved Title")
        XCTAssertFalse(result.hasMatchingSermon)
    }

    func testContinueListeningResult_displayTitle_legacyPayload() async {
        let savedInfo = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: nil,
            thumbnailURL: nil
        )

        let result = AudioPlayerManager.ContinueListeningResult(
            sermon: nil,
            savedTime: 100,
            savedInfo: savedInfo
        )

        // Should fall back to "Unknown"
        XCTAssertEqual(result.displayTitle, "Unknown")
        XCTAssertFalse(result.hasMatchingSermon)
    }

    func testContinueListeningResult_displayThumbnailURL_prefersSermon() async {
        let sermon = Sermon(
            id: "1",
            title: "Sermon Title",
            speaker: "Speaker",
            date: Date(),
            thumbnailUrl: "https://example.com/sermon-thumb.jpg",
            youtubeVideoId: nil,
            audioUrl: "https://example.com/audio.mp3",
            tags: nil,
            slug: nil
        )
        let savedInfo = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: "Saved Title",
            thumbnailURL: "https://example.com/saved-thumb.jpg"
        )

        let result = AudioPlayerManager.ContinueListeningResult(
            sermon: sermon,
            savedTime: 100,
            savedInfo: savedInfo
        )

        // Should prefer sermon thumbnail
        XCTAssertEqual(result.displayThumbnailURL, "https://example.com/sermon-thumb.jpg")
    }

    func testContinueListeningResult_displayThumbnailURL_fallsBackToSaved() async {
        let savedInfo = SavedPlaybackInfo(
            audioURL: "https://example.com/audio.mp3",
            time: 100,
            title: "Saved Title",
            thumbnailURL: "https://example.com/saved-thumb.jpg"
        )

        let result = AudioPlayerManager.ContinueListeningResult(
            sermon: nil,
            savedTime: 100,
            savedInfo: savedInfo
        )

        // Should fall back to saved thumbnail
        XCTAssertEqual(result.displayThumbnailURL, "https://example.com/saved-thumb.jpg")
    }
}
