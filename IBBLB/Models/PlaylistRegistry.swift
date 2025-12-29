import Foundation

// MARK: - Playlist Kind

/// Categorizes playlists by their organizational structure
enum PlaylistKind: String, Codable, CaseIterable, Sendable {
    /// Regular yearly playlists (e.g., "Predicaciones 2025")
    case yearBucket = "year_bucket"
    /// Annual events/conferences (e.g., "Conferencia de Jóvenes 2025")
    case event
    /// Timeless categories (e.g., "Anuncios", "Música")
    case category
    /// Multi-year series with stable identity
    case series
    /// Podcast-specific playlists
    case podcast
}

// MARK: - Playlist Content Type

/// What type of content the playlist contains
enum PlaylistContentType: String, Codable, CaseIterable, Sendable {
    case sermon
    case announcement
    case music
    case skit
    case podcast
    case other
}

// MARK: - Playlist Registry Item

/// A playlist entry in the registry
/// Single source of truth for YouTube playlist metadata
struct PlaylistRegistryItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let youtubePlaylistId: String
    let title: String
    let kind: PlaylistKind
    let contentType: PlaylistContentType
    let seriesId: String?
    let year: Int?
    let slug: String
    let tags: [String]
    let aliases: [String]
    let shortCode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case youtubePlaylistId = "youtube_playlist_id"
        case title
        case kind
        case contentType = "content_type"
        case seriesId = "series_id"
        case year
        case slug
        case tags
        case aliases
        case shortCode = "short_code"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PlaylistRegistryItem, rhs: PlaylistRegistryItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Scored Playlist Result

/// A playlist with its search relevance score
struct ScoredPlaylist: Sendable {
    let playlist: PlaylistRegistryItem
    let score: Int
}

// MARK: - Playlist Search Result

/// Result of searching the playlist registry
struct PlaylistSearchResult: Sendable {
    /// Matched playlists sorted by relevance
    let playlists: [PlaylistRegistryItem]
    /// YouTube playlist IDs for fetching sermons
    var playlistIds: [String] {
        playlists.map(\.youtubePlaylistId)
    }
    /// Whether any playlists were matched
    var hasMatches: Bool {
        !playlists.isEmpty
    }
}

// MARK: - Playlist Registry Cache

/// Cached playlist registry data with metadata for invalidation
struct PlaylistRegistryCache: Sendable {
    let items: [PlaylistRegistryItem]
    let cachedAt: Date
    let schemaVersion: Int

    /// Check if cache is still valid
    nonisolated func isValid() -> Bool {
        let age = Date().timeIntervalSince(cachedAt)
        let isNotExpired = age < SearchConfig.cacheTTL
        let isCorrectVersion = schemaVersion == SearchConfig.cacheSchemaVersion
        return isNotExpired && isCorrectVersion
    }
}

// MARK: - Codable conformance (nonisolated for actor compatibility)

extension PlaylistRegistryCache: Codable {
    private enum CodingKeys: String, CodingKey {
        case items, cachedAt, schemaVersion
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([PlaylistRegistryItem].self, forKey: .items)
        cachedAt = try container.decode(Date.self, forKey: .cachedAt)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
        try container.encode(cachedAt, forKey: .cachedAt)
        try container.encode(schemaVersion, forKey: .schemaVersion)
    }
}
