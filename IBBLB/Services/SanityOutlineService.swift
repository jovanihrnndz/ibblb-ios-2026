import Foundation

/// Service for fetching sermon outlines from Sanity CMS
struct SanityOutlineService {
    private let client: APIClient

    nonisolated init(client: APIClient? = nil) {
        self.client = client ?? APIClient()
    }

    // MARK: - Input Validation

    /// Validates and sanitizes input to prevent GROQ injection attacks
    /// Only allows alphanumeric characters, hyphens, and underscores
    private func sanitizeInput(_ input: String) -> String? {
        // YouTube IDs are typically 11 characters: alphanumeric, hyphens, underscores
        // Slugs can be longer but follow similar pattern
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))

        // Check if all characters are allowed
        guard input.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            #if DEBUG
            print("⚠️ SanityOutlineService: Invalid characters detected in input: '\(input)'")
            #endif
            return nil
        }

        // Length validation (reasonable limits)
        guard input.count >= 1 && input.count <= 200 else {
            #if DEBUG
            print("⚠️ SanityOutlineService: Input length out of bounds: \(input.count)")
            #endif
            return nil
        }

        return input
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
                // Escape quotes and backslashes to prevent GROQ injection
                let escapedSlug = escapeGroqString(slug)
                query = buildQuery(filter: "slug.current == \"\(escapedSlug)\"")
            case .byYouTubeId(let youtubeId):
                // Escape quotes and backslashes to prevent GROQ injection
                let escapedYoutubeId = escapeGroqString(youtubeId)
                query = buildQuery(filter: "youtubeId == \"\(escapedYoutubeId)\"")
            }
            return [URLQueryItem(name: "query", value: query)]
        }

        /// Escapes special characters in GROQ query strings to prevent injection
        private func escapeGroqString(_ str: String) -> String {
            str.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"")
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
        // Validate and sanitize input to prevent injection attacks
        guard let sanitizedSlug = sanitizeInput(slug) else {
            #if DEBUG
            print("❌ SanityOutlineService: Invalid slug format rejected: '\(slug)'")
            #endif
            return nil
        }

        do {
            let response: SanityResponse<SermonOutline?> = try await client.request(
                SanityOutlineEndpoint.bySlug(sanitizedSlug)
            )
            if let outline = response.result, outline.hasContent {
                return outline
            }
            return nil
        } catch {
            #if DEBUG
            print("❌ SanityOutlineService: Failed to fetch outline")
            #endif
            return nil
        }
    }

    /// Fetch outline by YouTube video ID (fallback method)
    /// - Parameter youtubeId: The YouTube video ID
    /// - Returns: SermonOutline if found, nil otherwise
    func fetchOutline(byYouTubeId youtubeId: String) async -> SermonOutline? {
        // Validate and sanitize input to prevent injection attacks
        guard let sanitizedYoutubeId = sanitizeInput(youtubeId) else {
            #if DEBUG
            print("❌ SanityOutlineService: Invalid YouTube ID format rejected: '\(youtubeId)'")
            #endif
            return nil
        }

        do {
            let response: SanityResponse<SermonOutline?> = try await client.request(
                SanityOutlineEndpoint.byYouTubeId(sanitizedYoutubeId)
            )
            if let outline = response.result, outline.hasContent {
                return outline
            }
            return nil
        } catch {
            #if DEBUG
            print("❌ SanityOutlineService: Failed to fetch outline")
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

        return nil
    }
}
