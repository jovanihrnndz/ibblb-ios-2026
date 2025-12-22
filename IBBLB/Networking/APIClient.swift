import Foundation

struct APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    nonisolated init(session: URLSession? = nil) {
        self.session = session ?? URLSession.shared
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try endpoint.urlRequest(config: APIConfig.self)
        
        #if DEBUG
        print("🚀 API Request: \(urlRequest.url?.absoluteString ?? "Invalid URL")")
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
                #if DEBUG
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Response Data (first 500 chars): \(String(jsonString.prefix(500)))")
                }
                #endif
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
                print("❌ Decoding Error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Raw Response: \(jsonString)")
                }
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
