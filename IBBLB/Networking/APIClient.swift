import Foundation

struct APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    // Shared certificate pinning delegate instance
    // Marked as nonisolated to allow access from nonisolated contexts
    nonisolated private static let pinningDelegate = CertificatePinningDelegate()

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
        if let url = urlRequest.url {
            print("🌐 URL: \(url.absoluteString)")
        }
        if let headers = urlRequest.allHTTPHeaderFields {
            print("📋 Headers: \(headers.keys.joined(separator: ", "))")
        }
        #endif

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                #if DEBUG
                print("❌ Invalid response type")
                #endif
                throw APIError.invalidResponse
            }

            #if DEBUG
            print("✅ API Response Status: \(httpResponse.statusCode)")
            print("📦 Response data size: \(data.count) bytes")
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
                    print("❌ Decoding Error: \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        print("   DecodingError details: \(decodingError)")
                    }
                    // SECURITY: Do not log response data - may contain sensitive information
                    #endif
                    throw APIError.decodingError(error)
                }
            case 401:
                #if DEBUG
                print("❌ Unauthorized (401)")
                #endif
                throw APIError.unauthorized
            default:
                #if DEBUG
                print("❌ Server error: \(httpResponse.statusCode)")
                #endif
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch let error as URLError {
            #if DEBUG
            print("❌ URLError: \(error.localizedDescription)")
            print("   Code: \(error.code.rawValue)")
            print("   Error code: \(error.code)")
            if let url = error.failingURL {
                print("   Failed URL: \(url.absoluteString)")
            }
            #endif
            throw APIError.requestFailed(error)
        } catch {
            #if DEBUG
            print("❌ Request failed with error: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
            #endif
            throw APIError.requestFailed(error)
        }
    }
}

