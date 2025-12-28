import SwiftUI

/// iPad-only sermon list for the content column of NavigationSplitView.
/// Uses selection binding instead of NavigationStack push.
struct iPadSermonsListView: View {
    @StateObject private var viewModel = SermonsViewModel()
    @Binding var selectedSermon: Sermon?
    @ObservedObject private var audioManager = AudioPlayerManager.shared

    private var listSermons: [Sermon] {
        viewModel.sermons
    }
    
    private var continueListeningSermon: Sermon? {
        guard let savedInfo = audioManager.getSavedPlaybackInfo() else { return nil }
        let savedURLString = savedInfo.url.trimmingCharacters(in: .whitespaces)
        guard !savedURLString.isEmpty else { return nil }
        
        return viewModel.sermons.first { sermon in
            guard let audioUrlString = sermon.audioUrl else { return false }
            let trimmedAudioUrl = audioUrlString.trimmingCharacters(in: .whitespaces)
            guard !trimmedAudioUrl.isEmpty else { return false }
            
            // Direct string comparison (most reliable)
            if trimmedAudioUrl == savedURLString {
                return true
            }
            
            // URL-based comparison (handles encoding differences)
            guard let savedURL = URL(string: savedURLString),
                  let sermonURL = URL(string: trimmedAudioUrl) else {
                return false
            }
            
            return sermonURL.absoluteString == savedURL.absoluteString
        }
    }
    
    private var continueListeningSavedTime: TimeInterval? {
        guard let savedInfo = audioManager.getSavedPlaybackInfo(),
              continueListeningSermon != nil else { return nil }
        return savedInfo.time
    }
    
    private func resumeListening() {
        guard let sermon = continueListeningSermon,
              let audioUrlString = sermon.audioUrl,
              let audioURL = URL(string: audioUrlString.trimmingCharacters(in: .whitespaces)) else {
            return
        }
        
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
        
        // Play audio (will auto-resume from saved position via AudioPlayerManager)
        audioManager.play(url: audioURL, title: sermon.title, artworkURL: artworkURL)
        // Note: Does NOT navigate - stays on list view
    }

    private var searchSuggestions: [String] {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        let titles = listSermons.map { $0.title }
        let uniqueTitles = Array(Set(titles))
        return uniqueTitles
            .filter { $0.lowercased().contains(lowercasedQuery) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutMetrics = LayoutMetrics(containerWidth: geometry.size.width)

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    BannerView()
                        .frame(maxWidth: .infinity)

                    ZStack {
                        Color(.systemGroupedBackground)
                            .ignoresSafeArea()

                        contentView(metrics: layoutMetrics)
                    }
                }

                // Search bar overlay
                searchBarOverlay(metrics: layoutMetrics)
            }
        }
        .task {
            await viewModel.loadInitial()
        }
    }

    // MARK: - Layout Metrics

    /// Width-driven layout configuration for adaptive grid sizing
    private struct LayoutMetrics {
        let containerWidth: CGFloat

        /// Minimum card width scales with container width
        var minCardWidth: CGFloat {
            if containerWidth >= 900 {
                // Very wide (full iPad landscape): larger cards, fewer columns
                return 360
            } else if containerWidth >= 600 {
                // Medium (iPad portrait or 2/3 split): medium cards
                return 320
            } else {
                // Narrow (1/3 split): smaller cards
                return 280
            }
        }

        /// Grid spacing scales slightly with width
        var gridSpacing: CGFloat {
            containerWidth >= 700 ? 20 : 16
        }

        /// Horizontal padding for content
        var horizontalPadding: CGFloat {
            containerWidth >= 700 ? 24 : 16
        }

        /// Search bar horizontal padding
        var searchBarPadding: CGFloat {
            containerWidth >= 700 ? 24 : 16
        }

        /// Search bar vertical padding
        var searchBarVerticalPadding: CGFloat {
            containerWidth >= 700 ? 16 : 12
        }

        /// Top padding below banner for search bar overlay
        /// (Banner is 140pt on iPad, 100pt on iPhone)
        var searchBarTopOffset: CGFloat {
            containerWidth >= 700 ? 140 : 100
        }

        /// Content top padding (below search bar area)
        var contentTopPadding: CGFloat {
            containerWidth >= 700 ? 60 : 50
        }
    }

    // MARK: - Search Bar

    private func searchBarOverlay(metrics: LayoutMetrics) -> some View {
        VStack(spacing: 0) {
            UIKitSearchBar(text: $viewModel.searchText, placeholder: "Search sermons")
                .padding(.horizontal, metrics.searchBarPadding)
                .padding(.vertical, metrics.searchBarVerticalPadding)

            if !searchSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(searchSuggestions, id: \.self) { suggestion in
                        Button {
                            viewModel.searchText = suggestion
                            dismissKeyboard()
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                Text(suggestion)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, metrics.searchBarPadding)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, metrics.searchBarTopOffset)
    }

    // MARK: - Content

    private func contentView(metrics: LayoutMetrics) -> some View {
        ScrollView {
            VStack(spacing: metrics.gridSpacing) {
                if viewModel.isLoading && viewModel.sermons.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else if viewModel.sermons.isEmpty {
                    emptyView
                } else {
                    sermonsGridContent(metrics: metrics)
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, metrics.contentTopPadding)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Sermons Grid (Selection-Driven, Width-Adaptive)

    private func sermonsGridContent(metrics: LayoutMetrics) -> some View {
        VStack(spacing: metrics.gridSpacing) {
            // Continue Listening Card (if available and no active playback)
            if audioManager.currentTrack == nil,
               let sermon = continueListeningSermon,
               let savedTime = continueListeningSavedTime {
                ContinueListeningCardView(
                    sermon: sermon,
                    savedTime: savedTime,
                    duration: nil, // Duration not available in list view
                    onCardTap: {
                        selectedSermon = sermon
                    },
                    onResume: resumeListening
                )
            }
            
            // Sermons grid
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: metrics.minCardWidth), spacing: metrics.gridSpacing)],
                spacing: metrics.gridSpacing
            ) {
                ForEach(listSermons) { sermon in
                    Button {
                        selectedSermon = sermon
                    } label: {
                        SermonCardView(sermon: sermon)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedSermon?.id == sermon.id ? Color.accentColor : Color.clear, lineWidth: 3)
                            )
                    }
                    .buttonStyle(SermonCardButtonStyle())
                }
            }
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView("Loading sermons...")
                .padding(.top, 40)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.amber)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text("Retry")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No sermons found")
                .font(.headline)
                .fontWeight(.bold)

            Text("Try searching for something else.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.clearSearch()
                } label: {
                    Text("Clear Search")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

#Preview {
    iPadSermonsListView(selectedSermon: .constant(nil))
}
