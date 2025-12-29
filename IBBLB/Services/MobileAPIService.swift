import Foundation

struct MobileAPIService {
    private let client: APIClient

    nonisolated init(client: APIClient? = nil) {
        self.client = client ?? APIClient()
    }

    // MARK: - Input Sanitization

    /// Sanitizes search input to prevent PostgREST query injection
    private func sanitizeSearchInput(_ search: String) -> String {
        // Remove PostgREST operators and special characters that could be used for injection
        let forbidden = ["*", ".", ",", "{", "}", "[", "]", "(", ")", "=", "&", "|", "<", ">", ";", ":", "'", "\"", "\\"]
        var sanitized = search
        forbidden.forEach { sanitized = sanitized.replacingOccurrences(of: $0, with: "") }
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validates tag input - only allows alphanumeric, spaces, hyphens, and underscores
    private func validateTag(_ tag: String) -> String? {
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_"))

        guard tag.count <= 100,
              tag.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return nil
        }

        return tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Validates year input - ensures it's a reasonable year value
    private func validateYear(_ year: Int) -> Int? {
        // Only allow years between 1900 and 2100
        guard year >= 1900 && year <= 2100 else {
            return nil
        }
        return year
    }
    
    enum MobileEndpoint: Endpoint {
        case giving
        
        var method: HTTPMethod { .get }
        
        var path: String {
            switch self {
            case .giving: return "/api/giving"
            }
        }
        
        var queryItems: [URLQueryItem]? { nil }
        
        var body: Data? { nil }
        var bearerToken: String? { nil }
        var customHeaders: [String : String]? { nil }
        var baseURLOverride: String? { nil }
    }
    
    enum SupabaseEndpoint: Endpoint {
        case livestreamEvents
        case events
        case sermons(limit: Int?, offset: Int?, search: String?, tag: String?, year: Int?)
        case sermonsByPlaylistIds(playlistIds: [String], limit: Int?)
        case playlistRegistry
        
        var method: HTTPMethod { .get }
        
        var path: String {
            switch self {
            case .livestreamEvents: return "/rest/v1/livestream_events"
            case .events: return "/rest/v1/events"
            case .sermons, .sermonsByPlaylistIds: return "/rest/v1/sermons"
            case .playlistRegistry: return "/rest/v1/playlist_registry"
            }
        }
        
        var queryItems: [URLQueryItem]? {
            switch self {
            case .livestreamEvents:
                return [URLQueryItem(name: "select", value: "*"), URLQueryItem(name: "order", value: "starts_at.desc"), URLQueryItem(name: "limit", value: "5")]
            case .events:
                return [URLQueryItem(name: "select", value: "*"), URLQueryItem(name: "order", value: "startDate.asc")]
            case .sermons(let limit, let offset, let search, let tag, let year):
                var items = [
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "order", value: "date.desc")
                ]
                if let limit = limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
                if let offset = offset { items.append(URLQueryItem(name: "offset", value: "\(offset)")) }

                // SECURITY: All user inputs are sanitized before being used in queries
                if let search = search, !search.isEmpty {
                    // Note: The actual sanitization happens in fetchSermons
                    // This assumes the search parameter passed here is already sanitized
                    items.append(URLQueryItem(name: "title", value: "ilike.*\(search)*"))
                }

                if let tag = tag, !tag.isEmpty {
                    // Note: The actual validation happens in fetchSermons
                    // This assumes the tag parameter passed here is already validated
                    items.append(URLQueryItem(name: "tags", value: "cs.{\(tag)}"))
                }

                if let year = year {
                    // Note: The actual validation happens in fetchSermons
                    // This assumes the year parameter passed here is already validated
                    items.append(URLQueryItem(name: "year", value: "eq.\(year)"))
                }

                return items

            case .sermonsByPlaylistIds(let playlistIds, let limit):
                var items = [
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "order", value: "date.desc")
                ]
                if let limit = limit {
                    items.append(URLQueryItem(name: "limit", value: "\(limit)"))
                }
                // Filter by playlist_id using PostgREST 'in' operator
                if !playlistIds.isEmpty {
                    let idsString = playlistIds.joined(separator: ",")
                    items.append(URLQueryItem(name: "playlist_id", value: "in.(\(idsString))"))
                }
                return items

            case .playlistRegistry:
                return [
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "order", value: "year.desc.nullslast,title.asc")
                ]
            }
        }
        
        var body: Data? { nil }
        var bearerToken: String? { nil }
        
        var customHeaders: [String : String]? {
            [
                "apikey": APIConfig.supabaseAnonKey,
                "Authorization": "Bearer \(APIConfig.supabaseAnonKey)"
            ]
        }
        
        var baseURLOverride: String? { APIConfig.supabaseURL }
    }
    
    func fetchSermons(limit: Int? = nil, offset: Int? = nil, search: String? = nil, tag: String? = nil, year: Int? = nil) async throws -> [Sermon] {
        // SECURITY: Sanitize all user inputs before making the request
        let sanitizedSearch: String? = {
            guard let search = search, !search.isEmpty else { return nil }
            let sanitized = sanitizeSearchInput(search)
            return sanitized.isEmpty ? nil : sanitized
        }()

        let validatedTag: String? = {
            guard let tag = tag, !tag.isEmpty else { return nil }
            return validateTag(tag)
        }()

        let validatedYear: Int? = {
            guard let year = year else { return nil }
            return validateYear(year)
        }()

        do {
            let response: [Sermon] = try await client.request(
                SupabaseEndpoint.sermons(
                    limit: limit,
                    offset: offset,
                    search: sanitizedSearch,
                    tag: validatedTag,
                    year: validatedYear
                )
            )
            return response
        } catch {
            // Don't log cancellation errors - they're expected when cancelling previous requests
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                throw error
            }
            if error is CancellationError {
                throw error
            }

            #if DEBUG
            print("❌ Supabase Sermons Error")
            #endif
            throw error
        }
    }

    /// Fetch sermons by playlist IDs (for hybrid search)
    func fetchSermonsByPlaylistIds(_ playlistIds: [String], limit: Int? = nil) async throws -> [Sermon] {
        guard !playlistIds.isEmpty else { return [] }

        do {
            let response: [Sermon] = try await client.request(
                SupabaseEndpoint.sermonsByPlaylistIds(playlistIds: playlistIds, limit: limit)
            )
            return response
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                throw error
            }
            if error is CancellationError {
                throw error
            }

            #if DEBUG
            print("❌ Supabase SermonsByPlaylistIds Error")
            #endif
            throw error
        }
    }

    /// Fetch the playlist registry from Supabase
    func fetchPlaylistRegistry() async throws -> [PlaylistRegistryItem] {
        do {
            let response: [PlaylistRegistryItem] = try await client.request(
                SupabaseEndpoint.playlistRegistry
            )
            return response
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                throw error
            }
            if error is CancellationError {
                throw error
            }

            #if DEBUG
            print("❌ Supabase PlaylistRegistry Error")
            #endif
            throw error
        }
    }

    enum SanityEndpoint: Endpoint {
        case events
        
        var method: HTTPMethod { .get }
        
        var path: String {
            switch self {
            case .events: return "/v2021-03-25/data/query/\(APIConfig.sanityDataset)"
            }
        }
        
        var queryItems: [URLQueryItem]? {
            switch self {
            case .events:
                let query = "*[_type == \"event\" && !(_id in path(\"drafts.**\"))] { _id, title, \"imageUrl\": image.asset->url, startDate, endDate, description, location, registrationEnabled } | order(startDate asc)"
                return [URLQueryItem(name: "query", value: query)]
            }
        }
        
        var body: Data? { nil }
        var bearerToken: String? { nil }
        var customHeaders: [String : String]? { nil }
        var baseURLOverride: String? { "https://\(APIConfig.sanityProjectID).api.sanity.io" }
    }
    
    func fetchEvents() async throws -> [Event] {
        // Fetching directly from Sanity.io
        let response: SanityResponse<[Event]> = try await client.request(SanityEndpoint.events)
        return response.result
    }
    
    func fetchLivestream() async throws -> LivestreamStatus {
        // Combine status and events to determine state
        let events: [LivestreamEvent] = try await client.request(SupabaseEndpoint.livestreamEvents)

        let now = Date()

        #if DEBUG
        print("📅 LiveStream: Fetched \(events.count) events")
        for event in events {
            print("   - \(event.title): startsAt=\(event.startsAt?.description ?? "nil")")
        }
        #endif

        // Find the latest completed event for 'lastEvent'
        // Sort by endsAt descending to get the most recent past event
        let lastEvent = events
            .filter { $0.endsAt != nil && $0.endsAt! < now }
            .sorted { ($0.endsAt ?? .distantPast) > ($1.endsAt ?? .distantPast) }
            .first

        // Find if any event is currently live
        let liveEvent = events.first { event in
            guard let starts = event.startsAt else { return false }
            let ends = event.endsAt ?? starts.addingTimeInterval(7200) // Default 2h
            return now >= starts && now <= ends.addingTimeInterval(3600) // 1h grace
        }

        // Find the next upcoming event: filter future events, sort by startDate ascending, take first
        let upcomingEvents = events
            .filter { $0.startsAt != nil && $0.startsAt! > now }
            .sorted { $0.startsAt! < $1.startsAt! }

        let nextUpcomingEvent = upcomingEvents.first

        #if DEBUG
        print("📅 LiveStream: Now = \(now)")
        print("📅 LiveStream: Live event = \(liveEvent?.title ?? "none")")
        print("📅 LiveStream: Upcoming events (sorted):")
        for event in upcomingEvents {
            print("   - \(event.title): \(event.startsAt!)")
        }
        print("📅 LiveStream: Next upcoming = \(nextUpcomingEvent?.title ?? "none")")
        #endif

        let state: LivestreamState
        if liveEvent != nil {
            state = .live
        } else if nextUpcomingEvent != nil {
            state = .upcoming
        } else {
            state = .offline
        }

        return LivestreamStatus(
            state: state,
            event: liveEvent ?? nextUpcomingEvent,
            lastEvent: lastEvent
        )
    }
    
    func fetchGiving() async throws -> GivingPage {
        let response: GivingPage = try await client.request(MobileEndpoint.giving)
        return response
    }
}
