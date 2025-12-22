import Foundation

/// Service for fetching sermon outlines from Sanity CMS
struct SanityOutlineService {
    private let client: APIClient

    nonisolated init(client: APIClient? = nil) {
        self.client = client ?? APIClient()
    }

    // MARK: - Sanity Endpoint

    private enum SanityOutlineEndpoint: Endpoint {
        case bySlug(String)
        case byYouTubeId(String)

        var method: HTTPMethod { .get }

        var path: String {
            "/v2021-03-25/data/query/\(APIConfig.sanityDataset)"
        }

        var queryItems: [URLQueryItem]? {
            let query: String
            switch self {
            case .bySlug(let slug):
                query = buildQuery(filter: "slug.current == \"\(slug)\"")
            case .byYouTubeId(let youtubeId):
                query = buildQuery(filter: "youtubeId == \"\(youtubeId)\"")
            }
            return [URLQueryItem(name: "query", value: query)]
        }

        var body: Data? { nil }
        var bearerToken: String? { nil }
        var customHeaders: [String: String]? { nil }
        var baseURLOverride: String? { "https://\(APIConfig.sanityProjectID).api.sanity.io" }

        /// Build GROQ query matching the website's query structure
        private func buildQuery(filter: String) -> String {
            """
            *[_type == "sermon" && \(filter)][0] {
              _id,
              title,
              youtubeId,
              "slug": slug.current,
              notesUrl,
              scriptureReferences,
              outline,
              outlineTitle,
              outlinePassage,
              outlineIntroduction,
              outlinePoints[] {
                title,
                scripture,
                body
              },
              outlineConclusion
            }
            """
        }
    }

    // MARK: - Public Methods

    /// Fetch outline by slug (primary method)
    /// - Parameter slug: The sermon slug
    /// - Returns: SermonOutline if found, nil otherwise
    func fetchOutline(bySlug slug: String) async -> SermonOutline? {
        do {
            let response: SanityResponse<SermonOutline?> = try await client.request(
                SanityOutlineEndpoint.bySlug(slug)
            )
            if let outline = response.result, outline.hasContent {
                #if DEBUG
                print("✅ SanityOutlineService: Found outline by slug '\(slug)'")
                #endif
                return outline
            }
            #if DEBUG
            print("⚠️ SanityOutlineService: No outline content for slug '\(slug)'")
            #endif
            return nil
        } catch {
            #if DEBUG
            print("❌ SanityOutlineService: Failed to fetch outline by slug '\(slug)': \(error)")
            #endif
            return nil
        }
    }

    /// Fetch outline by YouTube video ID (fallback method)
    /// - Parameter youtubeId: The YouTube video ID
    /// - Returns: SermonOutline if found, nil otherwise
    func fetchOutline(byYouTubeId youtubeId: String) async -> SermonOutline? {
        do {
            let response: SanityResponse<SermonOutline?> = try await client.request(
                SanityOutlineEndpoint.byYouTubeId(youtubeId)
            )
            if let outline = response.result, outline.hasContent {
                #if DEBUG
                print("✅ SanityOutlineService: Found outline by youtubeId '\(youtubeId)'")
                #endif
                return outline
            }
            #if DEBUG
            print("⚠️ SanityOutlineService: No outline content for youtubeId '\(youtubeId)'")
            #endif
            return nil
        } catch {
            #if DEBUG
            print("❌ SanityOutlineService: Failed to fetch outline by youtubeId '\(youtubeId)': \(error)")
            #endif
            return nil
        }
    }

    /// Fetch outline using matching logic: try slug first, then fall back to youtubeId
    /// - Parameters:
    ///   - slug: Optional sermon slug
    ///   - youtubeId: Optional YouTube video ID
    /// - Returns: SermonOutline if found, nil otherwise
    func fetchOutline(slug: String?, youtubeId: String?) async -> SermonOutline? {
        // Try slug first
        if let slug = slug, !slug.isEmpty {
            if let outline = await fetchOutline(bySlug: slug) {
                return outline
            }
        }

        // Fall back to youtubeId
        if let youtubeId = youtubeId, !youtubeId.isEmpty {
            if let outline = await fetchOutline(byYouTubeId: youtubeId) {
                return outline
            }
        }

        #if DEBUG
        print("⚠️ SanityOutlineService: No outline found for slug='\(slug ?? "nil")' or youtubeId='\(youtubeId ?? "nil")'")
        #endif
        return nil
    }
}
