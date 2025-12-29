import Foundation
import Combine

@MainActor
class SermonsViewModel: ObservableObject {
    @Published var sermons: [Sermon] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchText: String = ""
    @Published var selectedYear: Int? = nil

    private let apiService: MobileAPIService
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedInitial = false
    private var lastSearchText: String = ""

    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService

        // Listen for search changes - only trigger after initial load and if text changed
        $searchText
            .dropFirst()
            .debounce(for: .seconds(SearchConfig.debounceInterval), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newSearchText in
                guard let self = self,
                      self.hasLoadedInitial,
                      newSearchText != self.lastSearchText else { return }
                self.lastSearchText = newSearchText
                Task {
                    await self.fetchSermons()
                }
            }
            .store(in: &cancellables)
    }

    func loadInitial() async {
        guard !hasLoadedInitial else { return }
        hasLoadedInitial = true
        await fetchSermons()
    }

    func refresh() async {
        // Also refresh the playlist registry cache
        _ = await PlaylistRegistryService.shared.refreshRegistry()
        await fetchSermons()
    }

    func setYearFilter(_ year: Int?) {
        selectedYear = year
        Task {
            await fetchSermons()
        }
    }

    func clearSearch() {
        searchText = ""
        lastSearchText = ""
    }

    private var fetchTask: Task<Void, Never>?

    private func fetchSermons() async {
        // Prevent concurrent fetches
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        // Cancel any previous pending task
        fetchTask?.cancel()

        fetchTask = Task { @MainActor in
            do {
                let fetchedSermons: [Sermon]

                if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Empty search: fetch all sermons with optional year filter
                    fetchedSermons = try await fetchAllSermons()
                } else {
                    // Hybrid search: combine playlist registry + text search
                    fetchedSermons = try await performHybridSearch(query: searchText)
                }

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                self.sermons = fetchedSermons
                #if DEBUG
                print("✅ Sermons loaded: \(fetchedSermons.count) items")
                #endif
            } catch {
                // Check for cancellation errors first - these are expected and should be silent
                if isCancellationError(error) {
                    return
                }

                // Only log and show errors for actual failures
                print("❌ API Error (Sermons): \(error)")
                self.errorMessage = "No se pudieron cargar los sermones. Inténtalo de nuevo."
            }

            // Only update loading state if task wasn't cancelled
            if !Task.isCancelled {
                self.isLoading = false
            }
        }

        await fetchTask?.value
    }

    // MARK: - Search Strategies

    /// Fetch all sermons (empty search case)
    private func fetchAllSermons() async throws -> [Sermon] {
        try await apiService.fetchSermons(
            limit: SearchConfig.defaultPageSize,
            offset: 0,
            search: nil,
            tag: nil,
            year: selectedYear
        )
    }

    /// Perform hybrid search: playlist registry + text search, combined and deduplicated
    private func performHybridSearch(query: String) async throws -> [Sermon] {
        // Step 1: Search playlist registry
        let playlistResult = await PlaylistRegistryService.shared.searchPlaylists(query)

        #if DEBUG
        print("🔍 Playlist search for '\(query)': \(playlistResult.playlists.count) matches")
        for playlist in playlistResult.playlists {
            print("   - \(playlist.title) (year: \(playlist.year ?? 0))")
        }
        #endif

        // Step 2: Parallel fetch - sermons by playlist IDs + text search
        async let playlistSermons = fetchSermonsByPlaylists(playlistResult)
        async let textSermons = fetchSermonsByTextSearch(query)

        let (fromPlaylists, fromText) = try await (playlistSermons, textSermons)

        #if DEBUG
        print("🔍 Playlist sermons: \(fromPlaylists.count), Text sermons: \(fromText.count)")
        #endif

        // Step 3: Combine and deduplicate by sermon ID
        var seenIds = Set<String>()
        var combined: [Sermon] = []

        // Add playlist sermons first (higher priority)
        for sermon in fromPlaylists {
            if !seenIds.contains(sermon.id) {
                seenIds.insert(sermon.id)
                combined.append(sermon)
            }
        }

        // Add text search results
        for sermon in fromText {
            if !seenIds.contains(sermon.id) {
                seenIds.insert(sermon.id)
                combined.append(sermon)
            }
        }

        // Step 4: Sort by date (newest first)
        combined.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        #if DEBUG
        print("🔍 Combined results: \(combined.count) sermons (deduplicated)")
        #endif

        return combined
    }

    /// Fetch sermons matching playlist IDs from registry search
    private func fetchSermonsByPlaylists(_ result: PlaylistSearchResult) async throws -> [Sermon] {
        guard result.hasMatches else { return [] }

        return try await apiService.fetchSermonsByPlaylistIds(
            result.playlistIds,
            limit: SearchConfig.maxPlaylistResults
        )
    }

    /// Fetch sermons by text search (title, description)
    private func fetchSermonsByTextSearch(_ query: String) async throws -> [Sermon] {
        // Normalize query for better matching
        let normalizedQuery = SearchUtilities.normalizeText(query)
        guard !normalizedQuery.isEmpty else { return [] }

        return try await apiService.fetchSermons(
            limit: SearchConfig.maxTextSearchResults,
            offset: 0,
            search: normalizedQuery,
            tag: nil,
            year: selectedYear
        )
    }

    // MARK: - Helpers

    private func isCancellationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        if error is CancellationError {
            return true
        }
        return false
    }
}
