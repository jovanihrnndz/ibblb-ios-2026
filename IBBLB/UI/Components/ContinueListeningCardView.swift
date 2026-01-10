//
//  ContinueListeningCardView.swift
//  IBBLB
//
//  Created by Auto on 2025-01-27.
//

import SwiftUI

struct ContinueListeningCardView: View {
    /// The continue listening result (contains sermon if available, or saved metadata)
    let result: AudioPlayerManager.ContinueListeningResult
    let duration: TimeInterval?
    let onCardTap: (() -> Void)?
    let onResume: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var useGridLayout: Bool {
        horizontalSizeClass == .regular
    }

    private var progress: Double {
        guard let duration = duration, duration > 0 else { return 0 }
        return min(result.savedTime / duration, 1.0)
    }

    /// Whether navigation is available (only when we have a matching sermon)
    private var canNavigate: Bool {
        result.hasMatchingSermon && onCardTap != nil
    }

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            thumbnailView
                .frame(width: useGridLayout ? 120 : 100, height: useGridLayout ? 68 : 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Content - tappable for navigation (only if sermon available)
            if canNavigate {
                Button(action: { onCardTap?() }) {
                    contentView
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue listening: \(result.displayTitle)")
                .accessibilityHint("Double tap to view sermon details")
                .accessibilityAddTraits(.isButton)
            } else {
                contentView
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Continue listening: \(result.displayTitle)")
            }

            // Resume button - separate button that doesn't trigger navigation
            Button(action: onResume) {
                Image(systemName: "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: useGridLayout ? 48 : 44, height: useGridLayout ? 48 : 44)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Resume playback")
            .accessibilityHint("Double tap to resume playing from where you left off")
            .accessibilityAddTraits(.isButton)
        }
        .padding(useGridLayout ? 20 : 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Continue Listening"))
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(result.displayTitle)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(.primary)

            // Progress bar (optional, only if duration known)
            if let duration = duration, duration > 0 {
                ProgressView(value: progress)
                    .tint(.accentColor)
                    .frame(height: 4)
            }

            // Time info
            Text(AudioPlayerManager.formatTime(result.savedTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thumbnailView: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                if let fallbackURLs = thumbnailFallbackURLs {
                    FallbackAsyncImage(urls: fallbackURLs) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } placeholder: {
                        Color(.systemGray5)
                    }
                } else {
                    Color(.systemGray6)
                }
            }
    }

    private var thumbnailFallbackURLs: [URL]? {
        // Prefer sermon data if available
        if let sermon = result.sermon {
            if let thumbnailUrlString = sermon.thumbnailUrl,
               !thumbnailUrlString.isEmpty {
                if let videoId = YouTubeThumbnail.videoId(from: thumbnailUrlString) {
                    return YouTubeThumbnail.fallbackURLs(videoId: videoId)
                }
                if let url = URL(string: thumbnailUrlString) {
                    return [url]
                }
            }

            if let videoId = sermon.youtubeVideoId,
               !videoId.trimmingCharacters(in: .whitespaces).isEmpty {
                let extractedId = YouTubeVideoIDExtractor.extractVideoID(from: videoId)
                if let id = extractedId {
                    return YouTubeThumbnail.fallbackURLs(videoId: id)
                }
            }
        }

        // Fallback to saved thumbnail URL
        if let thumbnailUrlString = result.displayThumbnailURL,
           let url = URL(string: thumbnailUrlString) {
            return [url]
        }

        return nil
    }
}

#Preview("With Sermon") {
    let sermon = Sermon(
        id: "1",
        title: "The Prodigal Son Returns",
        speaker: "Pastor John Doe",
        date: Date(),
        thumbnailUrl: nil,
        youtubeVideoId: "dQw4w9WgXcQ",
        audioUrl: "https://example.com/audio.mp3",
        tags: nil,
        slug: nil
    )
    let savedInfo = SavedPlaybackInfo(
        audioURL: "https://example.com/audio.mp3",
        time: 1250,
        title: sermon.title,
        thumbnailURL: nil
    )
    let result = AudioPlayerManager.ContinueListeningResult(
        sermon: sermon,
        savedTime: 1250,
        savedInfo: savedInfo
    )
    return ContinueListeningCardView(
        result: result,
        duration: 3600,
        onCardTap: {},
        onResume: {}
    )
    .padding()
}

#Preview("Offline Fallback") {
    let savedInfo = SavedPlaybackInfo(
        audioURL: "https://example.com/audio.mp3",
        time: 1250,
        title: "Saved Sermon Title",
        thumbnailURL: "https://example.com/thumbnail.jpg"
    )
    let result = AudioPlayerManager.ContinueListeningResult(
        sermon: nil,
        savedTime: 1250,
        savedInfo: savedInfo
    )
    return ContinueListeningCardView(
        result: result,
        duration: nil,
        onCardTap: nil,
        onResume: {}
    )
    .padding()
}

