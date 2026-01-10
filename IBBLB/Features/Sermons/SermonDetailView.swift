//
//  SermonDetailView.swift
//  IBBLB
//
//  Created by jovani hernandez on 7/6/25.
//

import SwiftUI

struct SermonDetailView: View {
    let sermon: Sermon
    @State private var outline: SermonOutline?
    @State private var isOutlineLoading = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let outlineService = SanityOutlineService()
    @ObservedObject private var audioManager = AudioPlayerManager.shared

    /// Video height scales with size class
    private var videoHeight: CGFloat {
        horizontalSizeClass == .regular ? 480 : 220
    }

    /// Max content width for readability on wide screens
    private var maxContentWidth: CGFloat {
        horizontalSizeClass == .regular ? 900 : .infinity
    }

    /// Section spacing scales with size class
    private var sectionSpacing: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }

    /// Horizontal padding scales with size class
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }

    var body: some View {
        VStack(spacing: 0) {
            BannerView()
                .frame(maxWidth: .infinity)

            ZStack(alignment: .top) {
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        // Spacer for video
                        Color.clear
                            .frame(height: videoHeight + 16)

                        // Metadata
                        if let speaker = sermon.speaker, !speaker.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)
                                Text(speaker)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Speaker: \(speaker)")
                        }

                        // Date and Audio Button Row
                        HStack(spacing: 12) {
                            if let date = sermon.date {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .accessibilityHidden(true)
                                    Text(date.formattedSermonDate)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Date: \(date.formattedSermonDate)")
                            }

                            if let audioURL = audioURL {
                                Button {
                                    playAudio(url: audioURL)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isCurrentlyPlaying(url: audioURL) ? "pause.fill" : "play.fill")
                                            .font(.caption2.weight(.semibold))
                                            .accessibilityHidden(true)
                                        Text(isCurrentlyPlaying(url: audioURL) ? String(localized: "Playing") : String(localized: "Play Audio"))
                                            .font(.footnote.weight(.semibold))
                                    }
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.12))
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isCurrentlyPlaying(url: audioURL) ? String(localized: "Pause") : String(localized: "Play"))
                                .accessibilityHint("Double tap to \(isCurrentlyPlaying(url: audioURL) ? "pause" : "play") the audio version of this sermon")
                                .accessibilityAddTraits(.isButton)
                            }

                            Spacer()
                        }

                        // Bosquejo/Outline Section
                        if let outline = outline {
                            SermonOutlineSectionView(outline: outline)
                                .padding(.top, 8)
                                .accessibilityLabel("Sermon outline")
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                    .frame(maxWidth: maxContentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                // Sticky video overlay with background
                VStack(spacing: 0) {
                    videoPlayerSection
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .frame(maxWidth: maxContentWidth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(.systemBackground))

                    Spacer()
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
        .task {
            await loadOutline()
        }
    }

    // MARK: - Video Player Section

    @ViewBuilder
    private var videoPlayerSection: some View {
        if let rawVideoId = sermon.youtubeVideoId,
           let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
            YouTubePlayerView(videoID: videoId)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(12)
                .frame(maxWidth: .infinity)
                .frame(height: videoHeight)
                .id(videoId)
                .accessibilityLabel("Video player: \(sermon.title)")
                .accessibilityHint("Double tap to play or pause the video")
        }
    }

    // MARK: - Outline Loading

    @State private var hasLoadedOutline = false

    private func loadOutline() async {
        guard !hasLoadedOutline && !isOutlineLoading else { return }
        hasLoadedOutline = true
        isOutlineLoading = true
        defer { isOutlineLoading = false }

        outline = await outlineService.fetchOutline(
            slug: sermon.slug,
            youtubeId: sermon.youtubeVideoId
        )
    }

    private func playAudio(url: URL) {
        let artworkURL: URL? = {
            var videoId: String?

            if let thumbnailString = sermon.thumbnailUrl,
               !thumbnailString.isEmpty {
                videoId = YouTubeThumbnail.videoId(from: thumbnailString)
            }

            if videoId == nil,
               let youtubeId = sermon.youtubeVideoId,
               !youtubeId.trimmingCharacters(in: .whitespaces).isEmpty {
                videoId = YouTubeVideoIDExtractor.extractVideoID(from: youtubeId)
            }

            if let id = videoId {
                return YouTubeThumbnail.url(videoId: id, quality: .maxres)
            }

            if let thumbnailString = sermon.thumbnailUrl,
               !thumbnailString.isEmpty,
               let url = URL(string: thumbnailString),
               !YouTubeThumbnail.isYouTubeThumbnail(url) {
                return url
            }

            return nil
        }()

        audioManager.play(url: url, title: sermon.title, artworkURL: artworkURL)
    }

    private func isCurrentlyPlaying(url: URL) -> Bool {
        audioManager.currentTrack?.audioURL == url && audioManager.isPlaying
    }

    private var audioURL: URL? {
        guard let audioUrlString = sermon.audioUrl else {
            return nil
        }
        let trimmed = audioUrlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }
}

#Preview {
    NavigationStack {
        SermonDetailView(sermon: Sermon(
            id: "1",
            title: "The Prodigal Son Returns: A Story of Grace and Redemption",
            speaker: "Pastor John Doe",
            date: Date(),
            thumbnailUrl: nil,
            youtubeVideoId: "dQw4w9WgXcQ",
            audioUrl: "https://example.com/audio.mp3",
            tags: ["Parables", "Grace"],
            slug: "prodigal-son-grace-redemption"
        ))
    }
}
