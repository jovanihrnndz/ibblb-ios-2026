# Comprehensive Sermon Search Implementation

## Goal

Implement human-friendly search in the iOS app that mirrors the web app's behavior. Users can search using short codes ("yc25"), Spanish terms ("jovenes"), English terms ("youth conference"), or full names ("Conferencia de Jóvenes 2025") and get comprehensive, relevant results.

## User Stories

| Search Query | Expected Result |
|--------------|-----------------|
| `yc25` | Youth Conference 2025 sermons |
| `jovenes` | All youth conference sermons (all years) |
| `Jóvenes 2025` | Youth Conference 2025 (handles accents) |
| `fundamentos` | Fundamentos conference sermons |
| `f25` | Fundamentos 2025 sermons |
| `conf` | All conference sermons (synonym expansion) |
| _(empty)_ | All sermons (no filter) |

## Data Model

### Supabase Table: `playlist_registry`

```sql
CREATE TABLE public.playlist_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  youtube_playlist_id TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('year_bucket', 'event', 'category', 'series', 'podcast')),
  content_type TEXT NOT NULL CHECK (content_type IN ('sermon', 'announcement', 'music', 'skit', 'podcast', 'other')),
  series_id TEXT,
  year INTEGER,
  slug TEXT UNIQUE NOT NULL,
  tags TEXT[] DEFAULT '{}',
  aliases TEXT[] DEFAULT '{}',
  short_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Indexes:**
- `youtube_playlist_id` (unique)
- `slug` (unique)
- `series_id`
- `year`
- `kind`
- `content_type`

**RLS:** Public read access via anon key.

### iOS Models

```swift
struct PlaylistRegistryItem: Codable, Identifiable {
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
}

enum PlaylistKind: String, Codable, CaseIterable {
    case yearBucket = "year_bucket"
    case event
    case category
    case series
    case podcast
}

enum PlaylistContentType: String, Codable, CaseIterable {
    case sermon
    case announcement
    case music
    case skit
    case podcast
    case other
}
```

## iOS Architecture

### New Files

| File | Purpose |
|------|---------|
| `Config/SearchConfig.swift` | Debounce interval, cache TTL, fetch limits |
| `Models/PlaylistRegistry.swift` | Data models for registry items |
| `Services/SearchUtilities.swift` | Text normalization, year extraction, synonyms |
| `Services/PlaylistRegistryService.swift` | Fetch, cache, search registry |
| `Resources/playlist_registry_fallback.json` | Bundled fallback data |

### Modified Files

| File | Changes |
|------|---------|
| `Services/MobileAPIService.swift` | Add `SupabaseEndpoint.playlistRegistry` |
| `Features/Sermons/SermonsViewModel.swift` | Implement hybrid search logic |

### Config Values (`SearchConfig.swift`)

```swift
enum SearchConfig {
    static let debounceInterval: TimeInterval = 0.5  // 500ms
    static let cacheTTL: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    static let maxPlaylistResults = 100
    static let maxTextSearchResults = 100
    static let cacheSchemaVersion = 1
}
```

## Search Algorithm

### Flow

```
User input → Normalize → Extract years → Expand synonyms
                              ↓
         ┌──────────────────────────────────────┐
         │          PARALLEL SEARCH             │
         ├──────────────────┬───────────────────┤
         │ Playlist Registry│  Supabase Sermons │
         │ (local search)   │  (text ilike)     │
         └────────┬─────────┴─────────┬─────────┘
                  │                   │
                  └─────────┬─────────┘
                            ↓
                  Combine + Deduplicate
                            ↓
                  Sort by date (newest)
                            ↓
                       Return results
```

### Scoring (Playlist Registry)

| Match Type | Score |
|------------|-------|
| Exact alias match | +100 |
| Contains query variant | +50 |
| All tokens match | +75 |
| Partial token match | +25 per token |
| Year match | +80 |

**Threshold:** Only include playlists with score > 0.

### Text Normalization

```swift
func normalizeText(_ input: String) -> String {
    input
        .lowercased()
        .folding(options: .diacriticInsensitive, locale: .current)
        .replacingOccurrences(of: "[^a-z0-9]", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespaces)
}
```

### Year Extraction

- 4-digit years: `2025`, `2024` → direct match
- 2-digit tokens: `25` → 2025, `yc25` → year 2025, text "yc"
- Range: 2000-2099

### Synonym Expansion

| Input | Expansions |
|-------|------------|
| `conf` | `conference`, `conferencia` |
| `jovenes` | `youth` |
| `youth` | `jovenes` |

## Caching Strategy

### Storage

- **Location:** UserDefaults
- **Keys:**
  - `PlaylistRegistry.data` - Cached registry items (JSON)
  - `PlaylistRegistry.cachedAt` - Timestamp of last fetch
  - `PlaylistRegistry.schemaVersion` - For cache invalidation

### Cache Flow

```
App Launch → Check cache age
                 ↓
         Cache valid (< 7 days)?
              ↓           ↓
            YES          NO
              ↓           ↓
         Use cache    Fetch from Supabase
                           ↓
                      Success?
                       ↓    ↓
                     YES   NO
                       ↓    ↓
                  Update   Use fallback JSON
                  cache    (bundled in app)
```

### Cache Invalidation

- TTL expired (> 7 days)
- Schema version mismatch
- Manual refresh (pull-to-refresh on sermons)

## API Contract

### Endpoint: Supabase Direct

```
GET /rest/v1/playlist_registry
  ?select=*
  &order=year.desc.nullslast,title.asc

Headers:
  apikey: {SUPABASE_ANON_KEY}
  Authorization: Bearer {SUPABASE_ANON_KEY}
```

### Response

```json
[
  {
    "id": "uuid",
    "youtube_playlist_id": "PL5NMvYQjJDiDbdfoGGf7Wj2GTNPu3mRnX",
    "title": "Conferencia de Jóvenes 2025",
    "kind": "event",
    "content_type": "sermon",
    "series_id": "youth-conference",
    "year": 2025,
    "slug": "youth-conference-2025",
    "tags": ["series:youth-conference", "year:2025"],
    "aliases": ["youth conference", "conferencia de jovenes", "jovenes"],
    "short_code": "yc",
    "created_at": "...",
    "updated_at": "..."
  }
]
```

## Rollout Plan

1. **Phase 1: Backend** - Create Supabase migration, apply, verify data
2. **Phase 2: iOS Models** - Add data models and config
3. **Phase 3: Utilities** - Add search utilities with unit tests
4. **Phase 4: Service** - Add playlist registry service with caching
5. **Phase 5: Integration** - Update SermonsViewModel with hybrid search
6. **Phase 6: Testing** - Manual testing of all search scenarios

**Fallback behavior:** If registry fetch fails, use bundled JSON. If that fails, fall back to current text-only search.

## Test Plan

### Unit Tests

1. `normalizeText("Jóvenes")` → `"jovenes"`
2. `extractYearTokens("yc25")` → `(years: [2025], normalized: "yc")`
3. `searchPlaylists("yc25")` → returns Youth Conference 2025 first

### Manual Test Scenarios

| Scenario | Expected |
|----------|----------|
| Empty search | All sermons displayed |
| "yc25" | Youth Conference 2025 sermons |
| "jovenes" | All youth conference years |
| "Jóvenes 2025" | Youth Conference 2025 (accent handling) |
| "fundamentos" | Fundamentos sermons |
| "f25" | Fundamentos 2025 |
| "conf" | All conference sermons |
| Offline mode | Uses cached/fallback registry |
| Cache expired | Fetches fresh data |
