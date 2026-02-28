import SwiftUI

#if canImport(UIKit)

/// iPad-only sermon list for the content column of NavigationSplitView.
/// Uses selection binding instead of NavigationStack push.
struct iPadSermonsListView: View {
    @ObservedObject var viewModel: SermonsViewModel
    @Binding var selectedSermon: Sermon?
    var showBanner: Bool = true
    @ObservedObject private var audioManager = AudioPlayerManager.shared

    init(viewModel: SermonsViewModel, selectedSermon: Binding<Sermon?>, showBanner: Bool = true) {
        self.viewModel = viewModel
        _selectedSermon = selectedSermon
        self.showBanner = showBanner
    }

    private var listSermons: [Sermon] {
        viewModel.sermons
    }

    // Continue listening info from shared helper (supports offline fallback)
    private var continueListeningInfo: AudioPlayerManager.ContinueListeningResult? {
        audioManager.getContinueListeningInfo(from: viewModel.sermons)
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
                    if showBanner {
                        BannerView()
                            .frame(maxWidth: .infinity)
                    }

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
            containerWidth >= 700 ? 22 : 12
        }

        /// Top padding below banner for search bar overlay
        /// (Banner is 140pt on iPad, 100pt on iPhone)
        var searchBarTopOffset: CGFloat {
            containerWidth >= 700 ? 140 : 100
        }

        /// Content top padding (below search bar area)
        var contentTopPadding: CGFloat {
            containerWidth >= 700 ? 80 : 60
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
        .padding(.top, showBanner ? metrics.searchBarTopOffset : 0)
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
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 16)
                    }
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, showBanner ? metrics.contentTopPadding : 8)
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
            // Slim resume bar (if available and no active playback)
            if audioManager.currentTrack == nil,
               let info = continueListeningInfo {
                sidebarResumeBar(info: info)
                    .padding(.top, 40)
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
                    .buttonStyle(.plain)
                    .onAppear { viewModel.loadMoreIfNeeded(currentItem: sermon) }
                }
            }
        }
    }

    // MARK: - Slim Resume Bar

    private func sidebarResumeBar(info: AudioPlayerManager.ContinueListeningResult) -> some View {
        HStack(spacing: 10) {
            // Thumbnail
            Group {
                if let urls = resumeThumbnailURLs(from: info) {
                    FallbackAsyncImage(urls: urls) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } placeholder: {
                        Color(.systemGray5)
                    }
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Text — taps navigate to sermon
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(Color.primary)
                Text("Resume · \(AudioPlayerManager.formatTime(info.savedTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if info.hasMatchingSermon { selectedSermon = info.sermon }
            }

            // Resume button
            Button { audioManager.resumeListening(from: info) } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    private func resumeThumbnailURLs(from info: AudioPlayerManager.ContinueListeningResult) -> [URL]? {
        if let sermon = info.sermon {
            if let thumbnailString = sermon.thumbnailUrl, !thumbnailString.isEmpty {
                if let videoId = YouTubeThumbnail.videoId(from: thumbnailString) {
                    return YouTubeThumbnail.fallbackURLs(videoId: videoId)
                }
                if let url = URL(string: thumbnailString) { return [url] }
            }
            if let youtubeId = sermon.youtubeVideoId,
               !youtubeId.trimmingCharacters(in: .whitespaces).isEmpty,
               let id = YouTubeVideoIDExtractor.extractVideoID(from: youtubeId) {
                return YouTubeThumbnail.fallbackURLs(videoId: id)
            }
        }
        if let urlString = info.displayThumbnailURL, let url = URL(string: urlString) {
            return [url]
        }
        return nil
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
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif
    }
}

#if canImport(UIKit)
#Preview {
    iPadSermonsListView(viewModel: SermonsViewModel(), selectedSermon: .constant(nil))
}
#endif

#else

struct iPadSermonsListView: View {
    var viewModel: SermonsViewModel
    @Binding var selectedSermon: Sermon?

    init(viewModel: SermonsViewModel, selectedSermon: Binding<Sermon?>) {
        self.viewModel = viewModel
        _selectedSermon = selectedSermon
    }

    var body: some View {
        EmptyView()
    }
}

#endif
