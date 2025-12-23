import SwiftUI

/// A persistent mini player bar that appears at the bottom of the screen when audio is playing.
/// Apple Podcasts-style design with maximum transparency and pill-shaped appearance.
struct AudioMiniPlayerBar: View {
    @ObservedObject var audioManager: AudioPlayerManager
    let onTap: () -> Void

    private let barHeight: CGFloat = 56
    private let thumbnailSize: CGFloat = 40
    private let cornerRadius: CGFloat = 28 // Pill shape (half of height)

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Thumbnail
                    thumbnailView

                    // Title
                    if let track = audioManager.currentTrack {
                        Text(track.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Play/Pause button
                    Button {
                        audioManager.togglePlayPause()
                    } label: {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
            
            // Progress bar (thin line at bottom, integrated into pill shape)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.2))
                        .frame(height: 2)

                    Rectangle()
                        .fill(Color.primary.opacity(0.7))
                        .frame(width: geometry.size.width * audioManager.progress, height: 2)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(height: barHeight)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let artworkURL = audioManager.currentTrack?.artworkURL {
            ZStack {
                // Background to prevent any black bars from showing
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: thumbnailSize, height: thumbnailSize)
                
                // Use fallback URLs for YouTube thumbnails, single URL for others
                if let fallbackURLs = thumbnailFallbackURLs(from: artworkURL) {
                    FallbackAsyncImage(urls: fallbackURLs) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: thumbnailSize, height: thumbnailSize)
                    } placeholder: {
                        placeholderImage
                            .overlay(ProgressView().scaleEffect(0.5))
                    }
                } else {
                    AsyncImage(url: artworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: thumbnailSize, height: thumbnailSize)
                        case .failure:
                            placeholderImage
                        case .empty:
                            placeholderImage
                                .overlay(ProgressView().scaleEffect(0.5))
                        @unknown default:
                            placeholderImage
                        }
                    }
                }
            }
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            placeholderImage
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
    
    /// Generates fallback URLs if the artwork URL is a YouTube thumbnail
    private func thumbnailFallbackURLs(from url: URL) -> [URL]? {
        guard YouTubeThumbnail.isYouTubeThumbnail(url) else {
            return nil
        }
        return YouTubeThumbnail.fallbackURLs(from: url)
    }

    private var placeholderImage: some View {
        Image("sermon-placeholder")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

#Preview {
    VStack {
        Spacer()
        AudioMiniPlayerBar(
            audioManager: .shared,
            onTap: {}
        )
    }
}
