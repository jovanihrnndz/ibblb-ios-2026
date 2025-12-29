import Foundation

/// Configuration constants for sermon search functionality
/// All properties are nonisolated to allow access from any actor context
enum SearchConfig {
    // MARK: - Debounce

    /// Debounce interval for search input (500ms)
    nonisolated static var debounceInterval: TimeInterval { 0.5 }

    // MARK: - Cache

    /// Cache time-to-live for playlist registry (7 days)
    nonisolated static var cacheTTL: TimeInterval { 7 * 24 * 60 * 60 }

    /// Schema version for cache invalidation
    /// Increment this when the PlaylistRegistryItem model or fallback data changes
    nonisolated static var cacheSchemaVersion: Int { 3 }

    // MARK: - Fetch Limits

    /// Maximum number of sermons to fetch from playlist matches
    nonisolated static var maxPlaylistResults: Int { 100 }

    /// Maximum number of sermons to fetch from text search
    nonisolated static var maxTextSearchResults: Int { 100 }

    /// Default page size for sermon pagination
    nonisolated static var defaultPageSize: Int { 20 }

    // MARK: - Scoring Thresholds

    /// Minimum score required for a playlist to be included in results
    nonisolated static var minimumPlaylistScore: Int { 1 }

    /// Score awarded for exact alias match
    nonisolated static var exactMatchScore: Int { 100 }

    /// Score awarded when query is contained in alias
    nonisolated static var containsMatchScore: Int { 50 }

    /// Score awarded when all search tokens match
    nonisolated static var allTokensMatchScore: Int { 75 }

    /// Score awarded per partial token match
    nonisolated static var partialTokenMatchScore: Int { 25 }

    /// Score boost when year matches
    nonisolated static var yearMatchBoost: Int { 80 }
}
