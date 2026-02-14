//
//  SermonDetailView.swift
//  IBBLB
//
//  Created by jovani hernandez on 7/6/25.
//

import SwiftUI

// MARK: - Layout Constants

private struct LayoutConstants {
    /// Max width for text content on iPad (readability)
    static let iPadTextMaxWidth: CGFloat = 720
    
    /// Horizontal padding for video on iPad (minimal to use more space)
    static let iPadVideoPadding: CGFloat = 12
    
    /// Horizontal padding for text content on iPad
    static let iPadTextPadding: CGFloat = 24
    
    /// Video aspect ratio (16:9)
    static let videoAspectRatio: CGFloat = 16/9
    static let videoAspectRatioInverse: CGFloat = 9/16
    
    /// Video height constraints (min/max bounds to avoid extremes)
    static let videoMinHeight: CGFloat = 240
    static let videoMaxHeight: CGFloat = 420
    
    /// Video height as percentage of available height on iPad (portrait/single column)
    static let videoHeightPercentage: CGFloat = 0.35
    
    /// Video height as percentage of available height on iPad landscape (2-column layout)
    static let iPadLandscapeVideoHeightPercentage: CGFloat = 0.40
    
    /// Outer horizontal padding for iPad landscape 2-column layout
    static let iPadLandscapeOuterPadding: CGFloat = 20
    
    /// Minimum width threshold for 2-column layout (handles Split View/Stage Manager)
    static let twoColumnThreshold: CGFloat = 1024
}

struct SermonDetailView: View {
    let sermon: Sermon
    let allSermons: [Sermon]
    @State private var outline: SermonOutline?
    @State private var isOutlineLoading = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let outlineService = SanityOutlineService()
    @ObservedObject private var audioManager = AudioPlayerManager.shared

    /// More sermons for sidebar (excludes current sermon, sorted by date desc, limited to 6)
    private var moreSermons: [Sermon] {
        Array(allSermons
            .filter { $0.id != sermon.id }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .prefix(6))
    }

    /// iPhone video height (fixed for compact layout)
    private var iPhoneVideoHeight: CGFloat {
        220
    }

    /// Video horizontal padding - minimal on iPad to use more space
    private var videoHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? LayoutConstants.iPadVideoPadding : 16
    }

    /// Text content max width - readability constraint only for text
    private var textMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? LayoutConstants.iPadTextMaxWidth : .infinity
    }

    /// Text horizontal padding (single source of truth)
    private var textHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? LayoutConstants.iPadTextPadding : 16
    }

    /// Section spacing scales with size class (compact on iPad portrait)
    private var sectionSpacing: CGFloat {
        if horizontalSizeClass == .regular {
            // Compact spacing on iPad portrait for more real estate
            return 16
        } else {
            return 16
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                BannerView()
                    .frame(maxWidth: .infinity)

                if shouldUseTwoColumnLayout(width: geometry.size.width) {
                    twoColumnLayout(geometry: geometry)
                } else {
                    singleColumnLayout(geometry: geometry)
                }
            }
            .background(Color(.systemBackground))
        }
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
    
    /// Determines if 2-column layout should be used based on available width (handles Split View/Stage Manager)
    private func shouldUseTwoColumnLayout(width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= LayoutConstants.twoColumnThreshold
    }
    
    /// Calculates dynamic video height for iPad based on available space
    /// - Parameters:
    ///   - availableWidth: Available width for the video (already accounting for padding/layout constraints)
    ///   - availableHeight: Available height for layout calculations
    ///   - heightPercentage: Optional height percentage (defaults to standard iPad portrait percentage)
    private func calculateVideoHeight(availableWidth: CGFloat, availableHeight: CGFloat, heightPercentage: CGFloat = LayoutConstants.videoHeightPercentage) -> CGFloat {
        guard horizontalSizeClass == .regular else {
            return iPhoneVideoHeight
        }
        
        // Calculate width-based height (16:9 aspect ratio)
        // availableWidth already accounts for padding/layout constraints
        let widthBasedHeight = availableWidth * LayoutConstants.videoAspectRatioInverse
        
        // Calculate height-based constraint (percentage of available height)
        let heightBasedMax = availableHeight * heightPercentage
        
        // Use the minimum of the two constraints, then clamp to min/max bounds
        let calculatedHeight = min(widthBasedHeight, heightBasedMax)
        return max(LayoutConstants.videoMinHeight, min(calculatedHeight, LayoutConstants.videoMaxHeight))
    }
    
    // MARK: - Layout Variants
    
    /// Single column layout (iPhone + iPad portrait)
    private func singleColumnLayout(geometry: GeometryProxy) -> some View {
        // Calculate video height accounting for padding that will be applied
        let availableWidth = geometry.size.width - (videoHorizontalPadding * 2)
        let videoHeight = calculateVideoHeight(
            availableWidth: availableWidth,
            availableHeight: geometry.size.height
        )
        
        return ZStack(alignment: .top) {
            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    // Spacer for video
                    Color.clear
                        .frame(height: videoHeight + 16)

                    textContent(isCompact: horizontalSizeClass == .regular)
                }
                .padding(.horizontal, textHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 100)
                .frame(maxWidth: textMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Sticky video overlay with background
            VStack(spacing: 0) {
                videoPlayerSection(dynamicHeight: videoHeight)
                    .padding(.horizontal, videoHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(Color(.systemBackground))

                Spacer()
            }
        }
    }
    
    /// Two column layout (iPad landscape / wide screens) with sticky sidebar
    private func twoColumnLayout(geometry: GeometryProxy) -> some View {
        // Sidebar width - increased for better visibility
        let sidebarWidth: CGFloat = 360
        
        // Calculate video height based on left column width with minimal video padding
        // Use reduced outer padding and landscape-specific video height percentage for hero feel
        let leftColumnWidth = geometry.size.width - (LayoutConstants.iPadLandscapeOuterPadding * 2) - 24 - sidebarWidth // Outer padding, spacing, sidebar
        let videoAvailableWidth = leftColumnWidth - (LayoutConstants.iPadVideoPadding * 2) // Video padding only
        let videoHeight = calculateVideoHeight(
            availableWidth: videoAvailableWidth,
            availableHeight: geometry.size.height,
            heightPercentage: LayoutConstants.iPadLandscapeVideoHeightPercentage
        )
        
        return HStack(alignment: .top, spacing: 24) {
            // Left column: video + content (scrollable)
            ScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    // VIDEO: full width of left column, only minimal padding (12px)
                    videoPlayerSection(dynamicHeight: videoHeight)
                        .padding(.horizontal, LayoutConstants.iPadVideoPadding)
                        .padding(.bottom, 8)
                    
                    // TEXT: use same horizontal padding as video to align outline with video
                    // Still apply maxWidth for readability
                    textContent(isCompact: false)
                        .frame(maxWidth: LayoutConstants.iPadTextMaxWidth, alignment: .leading)
                        .padding(.horizontal, LayoutConstants.iPadVideoPadding)
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .frame(maxWidth: .infinity)
            
            // Right column: actions sidebar (sticky, static)
            VStack(alignment: .leading, spacing: 16) {
                // Action buttons
                VStack(spacing: 12) {
                    if let audioURL = audioURL {
                        Button {
                            playAudio(url: audioURL)
                        } label: {
                            HStack {
                                Image(systemName: isCurrentlyPlaying(url: audioURL) ? "pause.fill" : "play.fill")
                                    .font(.body.weight(.semibold))
                                Text(isCurrentlyPlaying(url: audioURL) ? String(localized: "Playing") : String(localized: "Play Audio"))
                                    .font(.body.weight(.semibold))
                                Spacer()
                            }
                            .foregroundColor(.accentColor)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        // Share action placeholder
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                            Text(String(localized: "Share"))
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Divider between actions and "More Sermons"
                Divider()
                    .padding(.vertical, 4)
                
                // More Sermons section (only show if we have sermons)
                if !moreSermons.isEmpty {
                    MoreSermonsSidebarSection(sermons: moreSermons, allSermons: allSermons)
                }
                
                Spacer()
            }
            .frame(width: sidebarWidth)
            .padding(.top, 8)
        }
        .padding(.horizontal, LayoutConstants.iPadLandscapeOuterPadding)
    }
    
    // MARK: - Content Components
    
    /// Reusable text content (metadata, outline, etc.)
    private func textContent(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // Metadata - compact one-line on iPad portrait
            if isCompact {
                compactMetadataRow
            } else {
                expandedMetadataRow
            }

            // Bosquejo/Outline Section
            if let outline = outline {
                SermonOutlineSectionView(outline: outline)
                    .padding(.top, isCompact ? 4 : 8)
                    .accessibilityLabel("Sermon outline")
            }
        }
    }
    
    /// Compact one-line metadata for iPad portrait (pastor + date + passage)
    private var compactMetadataRow: some View {
        // Support Dynamic Type accessibility sizes (allow 2 lines)
        let isAccessibilitySize = dynamicTypeSize >= .accessibility1
        let lineLimit = isAccessibilitySize ? 2 : 1
        
        return HStack(spacing: 12) {
            // Speaker
            if let speaker = sermon.speaker, !speaker.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(speaker)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(lineLimit)
                        .truncationMode(.tail)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Speaker: \(speaker)")
            }
            
            // Date
            if let date = sermon.date {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(date.formattedSermonDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(lineLimit)
                        .truncationMode(.tail)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Date: \(date.formattedSermonDate)")
            }
            
            // Passage (from outline if available)
            if let outline = outline, let passage = outline.outlinePassage, !passage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(passage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(lineLimit)
                        .truncationMode(.tail)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Scripture: \(passage)")
            }
            
            Spacer()
            
            // Audio button (compact)
            if let audioURL = audioURL {
                Button {
                    playAudio(url: audioURL)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCurrentlyPlaying(url: audioURL) ? "pause.fill" : "play.fill")
                            .font(.caption2.weight(.semibold))
                            .accessibilityHidden(true)
                        Text(isCurrentlyPlaying(url: audioURL) ? String(localized: "Playing") : String(localized: "Play Audio"))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
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
        }
    }
    
    /// Expanded metadata for iPhone and 2-column layout
    private var expandedMetadataRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Speaker
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
        }
    }

    // MARK: - Video Player Section

    @ViewBuilder
    private func videoPlayerSection(dynamicHeight: CGFloat) -> some View {
        if let rawVideoId = sermon.youtubeVideoId,
           let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
            let usePolishedContainer = horizontalSizeClass == .regular
            
            let videoContent = YouTubePlayerView(videoID: videoId)
                .aspectRatio(LayoutConstants.videoAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: dynamicHeight)
                .id(videoId)
                .accessibilityLabel("Video player: \(sermon.title)")
                .accessibilityHint("Double tap to play or pause the video")

            if usePolishedContainer {
                // iPad: polished container with shadow and rounded corners
                videoContent
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            } else {
                // iPhone: simple rounded corners (existing behavior)
                videoContent
                    .cornerRadius(12)
            }
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

// MARK: - More Sermons Sidebar Section

private struct MoreSermonsSidebarSection: View {
    let sermons: [Sermon]
    let allSermons: [Sermon]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "More Sermons"))
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(sermons) { sermon in
                    NavigationLink(destination: SermonDetailView(sermon: sermon, allSermons: allSermons)) {
                        MoreSermonsRowView(sermon: sermon)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - More Sermons Row View

private struct MoreSermonsRowView: View {
    let sermon: Sermon
    
    /// Generates thumbnail URLs for the sermon (similar to SermonCardView)
    private var thumbnailURLs: [URL]? {
        // Try thumbnailUrl first
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (60x40)
            Group {
                if let urls = thumbnailURLs {
                    FallbackAsyncImage(urls: urls) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        thumbnailPlaceholder
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 60, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Title and date
            VStack(alignment: .leading, spacing: 4) {
                Text(sermon.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let date = sermon.date {
                    Text(date.formattedSermonDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
    
    private var thumbnailPlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "play.rectangle.fill")
                .font(.caption)
                .foregroundColor(Color(.systemGray3))
        }
    }
}

#Preview {
    NavigationStack {
        SermonDetailView(
            sermon: Sermon(
                id: "1",
                title: "The Prodigal Son Returns: A Story of Grace and Redemption",
                speaker: "Pastor John Doe",
                date: Date(),
                thumbnailUrl: nil,
                youtubeVideoId: "dQw4w9WgXcQ",
                audioUrl: "https://example.com/audio.mp3",
                tags: ["Parables", "Grace"],
                slug: "prodigal-son-grace-redemption"
            ),
            allSermons: []
        )
    }
}
