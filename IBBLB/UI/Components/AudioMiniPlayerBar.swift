import SwiftUI

/// A persistent mini player bar that appears at the bottom of the screen when audio is playing.
/// Apple Podcasts-style design with maximum transparency and pill-shaped appearance.
struct AudioMiniPlayerBar: View {
    @ObservedObject var audioManager: AudioPlayerManager
    let onTap: () -> Void

    private var barHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 76 : 68
    }
    private let thumbnailSize: CGFloat = 48
    private var cornerRadius: CGFloat {
        barHeight / 2 // Pill shape (half of height)
    }

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
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                            .contentTransition(.symbolEffect(.replace.downUp))
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioManager.isPlaying)
                    .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Play")
                    .accessibilityHint("Double tap to \(audioManager.isPlaying ? "pause" : "play") audio")
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
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
                        .animation(.linear(duration: 0.3), value: audioManager.progress)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
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
