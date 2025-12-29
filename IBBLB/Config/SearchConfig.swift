import Foundation

/// Configuration constants for sermon search functionality
enum SearchConfig: Sendable {
    // MARK: - Debounce

    /// Debounce interval for search input (500ms)
    static let debounceInterval: TimeInterval = 0.5

    // MARK: - Cache

    /// Cache time-to-live for playlist registry (7 days)
    static let cacheTTL: TimeInterval = 7 * 24 * 60 * 60

    /// Schema version for cache invalidation
    /// Increment this when the PlaylistRegistryItem model changes
    static let cacheSchemaVersion: Int = 1

    // MARK: - Fetch Limits

    /// Maximum number of sermons to fetch from playlist matches
    static let maxPlaylistResults: Int = 100

    /// Maximum number of sermons to fetch from text search
    static let maxTextSearchResults: Int = 100

    /// Default page size for sermon pagination
    static let defaultPageSize: Int = 20

    // MARK: - Scoring Thresholds

    /// Minimum score required for a playlist to be included in results
    static let minimumPlaylistScore: Int = 1

    /// Score awarded for exact alias match
    static let exactMatchScore: Int = 100

    /// Score awarded when query is contained in alias
    static let containsMatchScore: Int = 50

    /// Score awarded when all search tokens match
    static let allTokensMatchScore: Int = 75

    /// Score awarded per partial token match
    static let partialTokenMatchScore: Int = 25

    /// Score boost when year matches
    static let yearMatchBoost: Int = 80
}
