//
//  SermonDetailView.swift
//  IBBLB
//
//  Created by jovani hernandez on 7/6/25.
//

import SwiftUI

struct SermonDetailView: View {
    let sermon: Sermon
    @State private var isAudioPlayerExpanded = false
    @State private var outline: SermonOutline?
    @State private var isOutlineLoading = false

    private let outlineService = SanityOutlineService()

    var body: some View {
        VStack(spacing: 0) {
            BannerView()
                .frame(maxWidth: .infinity)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // YouTube Video Player
                    if let rawVideoId = sermon.youtubeVideoId,
                       let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
                        YouTubePlayerView(videoID: videoId)
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity)
                            .onAppear {
                                #if DEBUG
                                print("✅ SermonDetailView: Rendering YouTube player with video ID: '\(videoId)' (raw: '\(rawVideoId)')")
                                #endif
                            }
                    } else {
                        EmptyView()
                            .onAppear {
                                #if DEBUG
                                if let rawVideoId = sermon.youtubeVideoId {
                                    print("❌ SermonDetailView: Failed to extract video ID from: '\(rawVideoId)'")
                                } else {
                                    print("⚠️ SermonDetailView: No YouTube video ID found for sermon: '\(sermon.title)'")
                                }
                                #endif
                            }
                    }
                    
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
                    
                    // Audio Player Section
                    if let audioURL = audioURL {
                        audioSection(audioURL: audioURL)
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
        .task {
            await loadOutline()
        }
    }

    // MARK: - Outline Loading

    private func loadOutline() async {
        isOutlineLoading = true
        defer { isOutlineLoading = false }

        outline = await outlineService.fetchOutline(
            slug: sermon.slug,
            youtubeId: sermon.youtubeVideoId
        )
    }
    
    // MARK: - Audio Section
    private func audioSection(audioURL: URL) -> some View {
        VStack(spacing: 0) {
            // Audio Card
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isAudioPlayerExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "waveform")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        if let speaker = sermon.speaker, !speaker.isEmpty {
                            Text(speaker)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        } else {
                            Text("Audio")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Action Indicator
                    Image(systemName: isAudioPlayerExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            
            // Expanded Audio Player
            if isAudioPlayerExpanded {
                AudioPlayerView(
                    url: audioURL,
                    title: sermon.title,
                    subtitle: sermon.speaker,
                    showInfo: false
                )
                .padding(.top, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
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
