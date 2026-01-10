import SwiftUI

struct SermonCardView: View {
    let sermon: Sermon
    
    // Platform detection
    private var isTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        thumbnailView
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: isTV ? 20 : 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: isTV ? 8 : 4, x: 0, y: 2)
            .accessibilityLabel("\(sermon.title)\(sermon.speaker.map { " by \($0)" } ?? "")")
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
                        loadingContent
                    }
                } else {
                    placeholderContent
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
    }
    
    /// Generates fallback URLs for the sermon thumbnail
    private var thumbnailFallbackURLs: [URL]? {
        // Try to get video ID from thumbnailUrl first
        if let thumbnailUrlString = sermon.thumbnailUrl,
           !thumbnailUrlString.isEmpty {
            // Check if it's a YouTube thumbnail URL and extract video ID
            if let videoId = YouTubeThumbnail.videoId(from: thumbnailUrlString) {
                return YouTubeThumbnail.fallbackURLs(videoId: videoId)
            }
            // If it's not a YouTube URL but exists, return as single URL array
            if let url = URL(string: thumbnailUrlString) {
                return [url]
            }
        }
        
        // Fallback to youtubeVideoId if available
        if let videoId = sermon.youtubeVideoId,
           !videoId.trimmingCharacters(in: .whitespaces).isEmpty {
            let extractedId = YouTubeVideoIDExtractor.extractVideoID(from: videoId)
            if let id = extractedId {
                return YouTubeThumbnail.fallbackURLs(videoId: id)
            }
        }
        
        return nil
    }

    private var loadingContent: some View {
        ZStack {
            Color(.systemGray5)
            ProgressView()
                .tint(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderContent: some View {
        ZStack {
            Color(.systemGray6)
            Image(systemName: "play.rectangle.fill")
                .font(isTV ? .system(size: 80) : .largeTitle) // Large decorative icon - size appropriate for placeholder
                .foregroundColor(Color(.systemGray3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SermonCardView(sermon: Sermon(
        id: "1",
        title: "The Prodigal Son Returns",
        speaker: "Pastor John Doe",
        date: Date(),
        thumbnailUrl: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        youtubeVideoId: "dQw4w9WgXcQ",
        audioUrl: nil,
        tags: ["Parables", "Grace"],
        slug: "prodigal-son-returns"
    ))
    .padding()
}
