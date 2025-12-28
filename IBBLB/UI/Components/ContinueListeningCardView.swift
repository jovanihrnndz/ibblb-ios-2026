//
//  ContinueListeningCardView.swift
//  IBBLB
//
//  Created by Auto on 2025-01-27.
//

import SwiftUI

struct ContinueListeningCardView: View {
    let sermon: Sermon
    let savedTime: TimeInterval
    let duration: TimeInterval?
    let onCardTap: () -> Void
    let onResume: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var useGridLayout: Bool {
        horizontalSizeClass == .regular
    }
    
    private var progress: Double {
        guard let duration = duration, duration > 0 else { return 0 }
        return min(savedTime / duration, 1.0)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            thumbnailView
                .frame(width: useGridLayout ? 120 : 100, height: useGridLayout ? 68 : 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Content - tappable for navigation
            Button(action: onCardTap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Continue Listening")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text(sermon.title)
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
                    Text(AudioPlayerManager.formatTime(savedTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Resume button - separate button that doesn't trigger navigation
            Button(action: onResume) {
                Image(systemName: "play.fill")
                    .font(.system(size: useGridLayout ? 20 : 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: useGridLayout ? 48 : 44, height: useGridLayout ? 48 : 44)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(useGridLayout ? 20 : 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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
        
        return nil
    }
}

#Preview {
    ContinueListeningCardView(
        sermon: Sermon(
            id: "1",
            title: "The Prodigal Son Returns",
            speaker: "Pastor John Doe",
            date: Date(),
            thumbnailUrl: nil,
            youtubeVideoId: "dQw4w9WgXcQ",
            audioUrl: "https://example.com/audio.mp3",
            tags: nil,
            slug: nil
        ),
        savedTime: 1250,
        duration: 3600,
        onCardTap: {},
        onResume: {}
    )
    .padding()
}

