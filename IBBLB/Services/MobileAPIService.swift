import Foundation



struct MobileAPIService {
    private let client: APIClient

    
    nonisolated init(client: APIClient? = nil) {
        self.client = client ?? APIClient()
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
        case sermons(limit: Int?, offset: Int?, search: String?, tag: String?)
        
        var method: HTTPMethod { .get }
        
        var path: String {
            switch self {
            case .livestreamEvents: return "/rest/v1/livestream_events"
            case .events: return "/rest/v1/events"
            case .sermons: return "/rest/v1/sermons"
            }
        }
        
        var queryItems: [URLQueryItem]? {
            switch self {
            case .livestreamEvents:
                return [URLQueryItem(name: "select", value: "*"), URLQueryItem(name: "order", value: "starts_at.desc"), URLQueryItem(name: "limit", value: "5")]
            case .events:
                return [URLQueryItem(name: "select", value: "*"), URLQueryItem(name: "order", value: "startDate.asc")]
            case .sermons(let limit, let offset, let search, let tag):
                var items = [
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "order", value: "date.desc")
                ]
                if let limit = limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
                if let offset = offset { items.append(URLQueryItem(name: "offset", value: "\(offset)")) }
                
                if let search = search, !search.isEmpty {
                    // Search in title using ILIKE with proper Supabase PostgREST syntax
                    // Supabase PostgREST uses * as wildcard: title=ilike.*search*
                    // URLQueryItem will encode * to %2A, which Supabase should handle
                    // But to be safe, we'll use the or() filter with multiple conditions
                    let encodedSearch = search.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: " "))) ?? search
                    items.append(URLQueryItem(name: "title", value: "ilike.*\(encodedSearch)*"))
                }
                
                if let tag = tag, !tag.isEmpty {
                    // Filter by tag in array column: tags=cs.{tag}
                    items.append(URLQueryItem(name: "tags", value: "cs.{\(tag)}"))
                }
                
                return items
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
    
    func fetchSermons(limit: Int? = nil, offset: Int? = nil, search: String? = nil, tag: String? = nil) async throws -> [Sermon] {
        do {
            let response: [Sermon] = try await client.request(SupabaseEndpoint.sermons(limit: limit, offset: offset, search: search, tag: tag))
            return response
        } catch {
            // Don't log cancellation errors - they're expected when cancelling previous requests
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                throw error // Re-throw but don't log
            }
            if error is CancellationError {
                throw error // Re-throw but don't log
            }
            
            #if DEBUG
            print("❌ Supabase Sermons Error: \(error)")
            if let url = try? SupabaseEndpoint.sermons(limit: limit, offset: offset, search: search, tag: tag).urlRequest(config: APIConfig.self).url {
                print("🔗 Request URL: \(url.absoluteString)")
            }
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
        
        // Find the latest completed event for 'lastEvent'
        let now = Date()
        let lastEvent = events.first { $0.endsAt != nil && $0.endsAt! < now }
        
        // Find if any event is currently live or upcoming
        let currentOrFuture = events.filter { $0.endsAt == nil || $0.endsAt! > now }
        let liveEvent = currentOrFuture.first { event in
            guard let starts = event.startsAt else { return false }
            let ends = event.endsAt ?? starts.addingTimeInterval(7200) // Default 2h
            return now >= starts && now <= ends.addingTimeInterval(3600) // 1h grace
        }
        
        let upcomingEvent = currentOrFuture.first { $0.startsAt != nil && $0.startsAt! > now }
        
        let state: LivestreamState
        if liveEvent != nil {
            state = .live
        } else if upcomingEvent != nil {
            state = .upcoming
        } else {
            state = .offline
        }
        
        return LivestreamStatus(
            state: state,
            event: liveEvent ?? upcomingEvent,
            lastEvent: lastEvent
        )
    }
    
    func fetchGiving() async throws -> GivingPage {
        let response: GivingPage = try await client.request(MobileEndpoint.giving)
        return response
    }
}
