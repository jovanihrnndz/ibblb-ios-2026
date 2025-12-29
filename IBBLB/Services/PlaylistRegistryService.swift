import Foundation

/// Service for fetching, caching, and searching the playlist registry
actor PlaylistRegistryService {

    // MARK: - Singleton

    static let shared = PlaylistRegistryService()

    // MARK: - Dependencies

    private let client: APIClient
    private let userDefaults: UserDefaults

    // MARK: - Cache Keys

    private enum CacheKeys {
        static let registryData = "PlaylistRegistry.data"
    }

    // MARK: - State

    private var cachedRegistry: [PlaylistRegistryItem]?
    private var isFetching = false

    // MARK: - Initialization

    init(client: APIClient = APIClient(), userDefaults: UserDefaults = .standard) {
        self.client = client
        self.userDefaults = userDefaults
    }

    // MARK: - Public API

    /// Get the playlist registry, fetching from cache or network as needed
    func getRegistry() async -> [PlaylistRegistryItem] {
        // Return in-memory cache if available and not empty
        if let cached = cachedRegistry, !cached.isEmpty {
            #if DEBUG
            print("📦 Using in-memory cache (\(cached.count) items)")
            #endif
            return cached
        }

        // Try to load from UserDefaults cache (only if valid AND not empty)
        if let cache = loadCacheFromDisk(), cache.isValid(), !cache.items.isEmpty {
            cachedRegistry = cache.items
            #if DEBUG
            print("💾 Loaded from disk cache (\(cache.items.count) items)")
            #endif
            return cache.items
        }

        // Fetch from network
        do {
            let items = try await fetchFromNetwork()
            // If network returns empty, use fallback (table might not exist)
            if items.isEmpty {
                #if DEBUG
                print("⚠️ Network returned empty, using fallback")
                #endif
                let fallback = loadFallbackRegistry()
                cachedRegistry = fallback
                return fallback
            }
            cachedRegistry = items
            saveCacheToDisk(items: items)
            return items
        } catch {
            #if DEBUG
            print("❌ Network failed: \(error), using fallback")
            #endif
            // Fall back to bundled JSON
            let fallback = loadFallbackRegistry()
            cachedRegistry = fallback
            return fallback
        }
    }

    /// Force refresh the registry from network
    func refreshRegistry() async -> [PlaylistRegistryItem] {
        do {
            let items = try await fetchFromNetwork()
            // If network returns empty, use fallback
            if items.isEmpty {
                #if DEBUG
                print("⚠️ PlaylistRegistry refresh returned empty, using fallback")
                #endif
                return loadFallbackRegistry()
            }
            cachedRegistry = items
            saveCacheToDisk(items: items)
            return items
        } catch {
            #if DEBUG
            print("❌ PlaylistRegistry refresh failed: \(error)")
            #endif
            // Return current cache or fallback
            return cachedRegistry ?? loadFallbackRegistry()
        }
    }

    /// Search playlists by query string with human-friendly matching
    func searchPlaylists(_ query: String) async -> PlaylistSearchResult {
        let registry = await getRegistry()

        #if DEBUG
        print("🔍 PlaylistRegistry search: query='\(query)', registry has \(registry.count) items")
        #endif

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return PlaylistSearchResult(playlists: [])
        }

        // Normalize query and extract years
        let normalizedQuery = SearchUtilities.normalizeText(query)
        let yearResult = SearchUtilities.extractYearTokens(normalizedQuery)
        let queryYears = yearResult.years
        let queryWithoutYears = yearResult.normalized

        // Expand synonyms to generate query variants
        let queryVariants = SearchUtilities.expandSynonyms(queryWithoutYears)
        var uniqueVariants = queryVariants
        if !queryWithoutYears.isEmpty {
            uniqueVariants.insert(queryWithoutYears)
        }

        #if DEBUG
        print("🔍 Normalized: '\(normalizedQuery)', years: \(queryYears), variants: \(uniqueVariants)")
        #endif

        // Build search tokens from query variants
        var searchTokens = Set<String>()
        for variant in uniqueVariants {
            let tokens = variant.split(separator: " ").map(String.init)
            for token in tokens where !token.isEmpty {
                searchTokens.insert(token)
            }
        }
        // Add full query variants as potential exact matches
        for variant in uniqueVariants where !variant.isEmpty {
            searchTokens.insert(variant)
        }

        // Score each playlist
        var scored: [ScoredPlaylist] = []

        for playlist in registry {
            let aliases = SearchUtilities.buildAliases(for: playlist)
            var score = 0

            // Check for exact alias matches (highest score)
            for alias in aliases {
                for variant in uniqueVariants where alias == variant {
                    score += SearchConfig.exactMatchScore
                    break
                }
                // Check if alias contains the full query variant
                for variant in uniqueVariants where !variant.isEmpty && alias.contains(variant) {
                    score += SearchConfig.containsMatchScore
                }
            }

            // Check for token matches
            let aliasText = aliases.joined(separator: " ")
            let matchingTokens = searchTokens.filter { token in
                !token.isEmpty && aliasText.contains(token)
            }

            if matchingTokens.count == searchTokens.count && !searchTokens.isEmpty {
                score += SearchConfig.allTokensMatchScore
            } else if !matchingTokens.isEmpty {
                score += SearchConfig.partialTokenMatchScore * matchingTokens.count
            }

            // Year match boost
            if !queryYears.isEmpty, let playlistYear = playlist.year {
                if queryYears.contains(playlistYear) {
                    score += SearchConfig.yearMatchBoost
                }
            }

            // Only include playlists with some match
            if score >= SearchConfig.minimumPlaylistScore {
                scored.append(ScoredPlaylist(playlist: playlist, score: score))
            }
        }

        // Sort by score (desc), then year (desc), then title (asc)
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            // Same score: prefer newer years
            if let lhsYear = lhs.playlist.year, let rhsYear = rhs.playlist.year {
                return lhsYear > rhsYear
            }
            if lhs.playlist.year != nil { return true }
            if rhs.playlist.year != nil { return false }
            // Same score, no year: sort by title
            return lhs.playlist.title < rhs.playlist.title
        }

        let playlists = scored.map(\.playlist)
        return PlaylistSearchResult(playlists: playlists)
    }

    /// Clear the cache (for testing or manual refresh)
    func clearCache() {
        cachedRegistry = nil
        userDefaults.removeObject(forKey: CacheKeys.registryData)
    }

    // MARK: - Private: Network

    private func fetchFromNetwork() async throws -> [PlaylistRegistryItem] {
        guard !isFetching else {
            // Wait for existing fetch to complete
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if let cached = cachedRegistry {
                return cached
            }
            throw APIError.invalidResponse
        }

        isFetching = true
        defer { isFetching = false }

        let service = MobileAPIService(client: client)
        let items: [PlaylistRegistryItem] = try await service.fetchPlaylistRegistry()

        #if DEBUG
        print("✅ PlaylistRegistry fetched \(items.count) items from network")
        #endif

        // If network returns empty, treat as error and fall back
        if items.isEmpty {
            #if DEBUG
            print("⚠️ PlaylistRegistry network returned 0 items, will use fallback")
            #endif
            throw APIError.invalidResponse
        }

        return items
    }

    // MARK: - Private: Disk Cache

    private func loadCacheFromDisk() -> PlaylistRegistryCache? {
        guard let data = userDefaults.data(forKey: CacheKeys.registryData) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(PlaylistRegistryCache.self, from: data)
            #if DEBUG
            print("✅ PlaylistRegistry loaded \(cache.items.count) items from cache")
            #endif
            return cache
        } catch {
            #if DEBUG
            print("⚠️ PlaylistRegistry cache decode failed: \(error)")
            #endif
            return nil
        }
    }

    private func saveCacheToDisk(items: [PlaylistRegistryItem]) {
        let cache = PlaylistRegistryCache(
            items: items,
            cachedAt: Date(),
            schemaVersion: SearchConfig.cacheSchemaVersion
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            userDefaults.set(data, forKey: CacheKeys.registryData)
            #if DEBUG
            print("✅ PlaylistRegistry cached \(items.count) items to disk")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ PlaylistRegistry cache save failed: \(error)")
            #endif
        }
    }

    // MARK: - Private: Fallback

    private func loadFallbackRegistry() -> [PlaylistRegistryItem] {
        guard let url = Bundle.main.url(
            forResource: "playlist_registry_fallback",
            withExtension: "json"
        ) else {
            #if DEBUG
            print("⚠️ PlaylistRegistry fallback JSON not found in bundle")
            #endif
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Don't use convertFromSnakeCase - the CodingKeys already define the mapping
            // The JSON uses snake_case keys which match the CodingKeys definitions
            let items = try decoder.decode([PlaylistRegistryItem].self, from: data)
            #if DEBUG
            print("✅ PlaylistRegistry loaded \(items.count) items from fallback")
            #endif
            cachedRegistry = items
            return items
        } catch {
            #if DEBUG
            print("❌ PlaylistRegistry fallback decode failed: \(error)")
            #endif
            return []
        }
    }
}
