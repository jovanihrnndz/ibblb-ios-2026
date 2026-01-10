import SwiftUI

/// Full-screen "Now Playing" view presented as a sheet.
/// Displays artwork, title, seek slider, time labels, and playback controls.
struct NowPlayingView: View {
    @ObservedObject var audioManager: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    @State private var sliderValue: Double = 0
    @State private var isDragging = false

    private let artworkSize: CGFloat = 320

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag indicator
                dragIndicator
                    .padding(.top, 8)

                Spacer()

                // Artwork
                artworkView
                    .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 40)

                // Title
                if let track = audioManager.currentTrack {
                    titleView(for: track)
                        .padding(.horizontal, 32)
                }

                Spacer()
                    .frame(height: 48)

                // Seek slider and time labels
                seekSection
                    .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 40)

                // Playback controls
                controlsSection

                Spacer()
                    .frame(height: 32)

                // Stop button
                stopButton

                Spacer()
                    .frame(minHeight: geometry.safeAreaInsets.bottom + 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .onAppear {
                sliderValue = audioManager.currentTime
            }
            .onChange(of: audioManager.currentTime) { _, newValue in
                if !isDragging {
                    sliderValue = newValue
                }
            }
        }
    }

    // MARK: - Subviews

    private var dragIndicator: some View {
        Capsule()
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .opacity(0.6)
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private func titleView(for track: AudioTrackInfo) -> some View {
        // Split title if it contains "–" (en-dash) or "-" (hyphen) separator
        let titleString = track.title
        let separators: [String] = ["–", "—", "-"]
        
        // Parse the title components outside of ViewBuilder
        let parsedTitle = parseTitleComponents(titleString, separators: separators)
        
        if let (titlePart, subtitlePart, _) = parsedTitle {
            // Title and artist/subtitle format
            VStack(spacing: 6) {
                Text(titlePart)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                Text(subtitlePart)
                    .font(.body.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        } else {
            // Just title
            Text(track.title)
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }
    
    /// Parses title string into components based on separators
    /// - Returns: Tuple of (titlePart, subtitlePart, separator) if split, nil otherwise
    private func parseTitleComponents(_ title: String, separators: [String]) -> (String, String, String)? {
        for separator in separators {
            if title.contains(separator) {
                let components = title.components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                if components.count >= 2 {
                    let titlePart = components[0]
                    let subtitlePart = components.dropFirst().joined(separator: " \(separator) ")
                    return (titlePart, subtitlePart, separator)
                }
                break
            }
        }
        return nil
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artworkURL = audioManager.currentTrack?.artworkURL {
            // Use fallback URLs for YouTube thumbnails, single URL for others
            if let fallbackURLs = thumbnailFallbackURLs(from: artworkURL) {
                FallbackAsyncImage(urls: fallbackURLs) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 30)
                                .scaleEffect(1.2)
                        }
                        .frame(width: artworkSize, height: artworkSize)
                } placeholder: {
                    placeholderArtwork
                        .overlay(
                            ProgressView()
                                .tint(.primary)
                        )
                }
                .frame(width: artworkSize, height: artworkSize)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .blur(radius: 30)
                                    .scaleEffect(1.2)
                            }
                        
                    case .failure:
                        placeholderArtwork
                    case .empty:
                        placeholderArtwork
                            .overlay(
                                ProgressView()
                                    .tint(.primary)
                            )
                    @unknown default:
                        placeholderArtwork
                    }
                }
                .frame(width: artworkSize, height: artworkSize)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
        } else {
            placeholderArtwork
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
        }
    }
    
    /// Generates fallback URLs if the artwork URL is a YouTube thumbnail
    private func thumbnailFallbackURLs(from url: URL) -> [URL]? {
        guard YouTubeThumbnail.isYouTubeThumbnail(url) else {
            return nil
        }
        return YouTubeThumbnail.fallbackURLs(from: url)
    }

    private var placeholderArtwork: some View {
        Image("sermon-placeholder")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }

    private var seekSection: some View {
        VStack(spacing: 12) {
            Slider(
                value: $sliderValue,
                in: 0...max(1, audioManager.duration)
            ) { editing in
                isDragging = editing
                audioManager.isScrubbing = editing
                if !editing {
                    audioManager.seek(to: sliderValue)
                }
            }
            .tint(.accentColor)
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(AudioPlayerManager.formatTime(isDragging ? sliderValue : audioManager.currentTime)) of \(AudioPlayerManager.formatTime(audioManager.duration))")
            .accessibilityHint("Swipe up or down to adjust playback position")

            HStack {
                Text(AudioPlayerManager.formatTime(isDragging ? sliderValue : audioManager.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)

                Spacer()

                Text(AudioPlayerManager.formatTime(audioManager.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            .accessibilityHidden(true)
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 56) {
            // Skip backward 15s
            Button {
                audioManager.skipBackward()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "gobackward.15")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                            .accessibilityHidden(true)
                    }
                    
                    Text("15")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip backward 15 seconds")
            .accessibilityHint("Double tap to skip backward 15 seconds")
            .accessibilityAddTraits(.isButton)

            // Play/Pause
            Button {
                audioManager.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 80, height: 80)

                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34, weight: .semibold)) // Large play/pause icon - size appropriate for prominent control
                        .foregroundColor(.white)
                        .offset(x: audioManager.isPlaying ? 0 : 3)
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .accessibilityHidden(true)
                }
                .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioManager.isPlaying)
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Play")
            .accessibilityHint("Double tap to \(audioManager.isPlaying ? "pause" : "play") audio")
            .accessibilityAddTraits(.isButton)

            // Skip forward 30s
            Button {
                audioManager.skipForward()
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "goforward.30")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.primary)
                            .accessibilityHidden(true)
                    }
                    
                    Text("30")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip forward 30 seconds")
            .accessibilityHint("Double tap to skip forward 30 seconds")
            .accessibilityAddTraits(.isButton)
        }
    }

    private var stopButton: some View {
        Button {
            audioManager.stop()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
                Text("Stop")
                    .font(.body.weight(.semibold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop playback")
        .accessibilityHint("Double tap to stop playback and close this view")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    NowPlayingView(audioManager: .shared)
}
