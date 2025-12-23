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

    private let outlineService = SanityOutlineService()
    private let audioManager = AudioPlayerManager.shared

    var body: some View {
        VStack(spacing: 0) {
            BannerView()
                .frame(maxWidth: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // YouTube Video Player
                    videoPlayerSection
                    
                    // Metadata
                    if let speaker = sermon.speaker, !speaker.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(speaker)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Date and Audio Button Row
                    HStack(spacing: 12) {
                        if let date = sermon.date {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(date.formattedSermonDate)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let audioURL = audioURL {
                            Button {
                                playAudio(url: audioURL)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isCurrentlyPlaying(url: audioURL) ? "pause.fill" : "play.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(isCurrentlyPlaying(url: audioURL) ? "Playing" : "Play Audio")
                                        .font(.system(size: 14, weight: .semibold))
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
                        }
                        
                        Spacer()
                    }

                    // Bosquejo/Outline Section
                    if let outline = outline {
                        SermonOutlineSectionView(outline: outline)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(content: {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        })
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
                .id(videoId) // Stable ID prevents reloading when same video
        } else {
            EmptyView()
        }
    }


    // MARK: - Outline Loading

    @State private var hasLoadedOutline = false

    private func loadOutline() async {
        // Only load once per sermon
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
            // Try to get video ID from thumbnailUrl or youtubeVideoId
            var videoId: String?
            
            if let thumbnailString = sermon.thumbnailUrl,
               !thumbnailString.isEmpty {
                // Extract video ID from thumbnail URL if it's a YouTube thumbnail
                videoId = YouTubeThumbnail.videoId(from: thumbnailString)
            }
            
            // Fallback to youtubeVideoId if we don't have a video ID yet
            if videoId == nil,
               let youtubeId = sermon.youtubeVideoId,
               !youtubeId.trimmingCharacters(in: .whitespaces).isEmpty {
                videoId = YouTubeVideoIDExtractor.extractVideoID(from: youtubeId)
            }
            
            // If we have a video ID, generate the best quality URL (maxresdefault)
            if let id = videoId {
                return YouTubeThumbnail.url(videoId: id, quality: .maxres)
            }
            
            // Fallback to original thumbnailUrl if it exists and isn't a YouTube URL
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

    // MARK: - Computed Properties
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
