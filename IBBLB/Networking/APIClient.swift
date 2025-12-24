import Foundation

struct APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    // Shared certificate pinning delegate instance
    private static let pinningDelegate = CertificatePinningDelegate()

    nonisolated init(session: URLSession? = nil) {
        if let session = session {
            // Use provided session (useful for testing)
            self.session = session
        } else {
            // Create session with certificate pinning delegate
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60

            self.session = URLSession(
                configuration: configuration,
                delegate: Self.pinningDelegate,
                delegateQueue: nil
            )
        }

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try endpoint.urlRequest(config: APIConfig.self)
        
        #if DEBUG
        print("🚀 API Request initiated")
        if let method = urlRequest.httpMethod {
            print("📝 Method: \(method)")
        }
        #endif

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        #if DEBUG
        print("✅ API Response Status: \(httpResponse.statusCode)")
        #endif

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoded = try decoder.decode(T.self, from: data)
                #if DEBUG
                if let array = decoded as? [Any] {
                    print("✅ Decoded \(array.count) items")
                } else {
                    print("✅ Decoding successful")
                }
                #endif
                return decoded
            } catch {
                #if DEBUG
                print("❌ Decoding Error")
                // SECURITY: Do not log response data - may contain sensitive information
                #endif
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}
