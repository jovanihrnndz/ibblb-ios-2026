import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

protocol Endpoint {
    var method: HTTPMethod { get }
    var path: String { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    var bearerToken: String? { get }
    var customHeaders: [String: String]? { get }
    var baseURLOverride: String? { get }
}

extension Endpoint {
    func urlRequest(config: APIConfig.Type) throws -> URLRequest {
        let base = baseURLOverride ?? config.baseURL
        
        // Validate base URL is not empty and is a valid URL
        guard !base.isEmpty else {
            #if DEBUG
            print("❌ Endpoint: Base URL is empty. Check APIConfig configuration.")
            #endif
            throw APIError.invalidURL
        }
        
        guard base.hasPrefix("http://") || base.hasPrefix("https://") else {
            #if DEBUG
            print("❌ Endpoint: Base URL is invalid (must start with http:// or https://): '\(base)'")
            #endif
            throw APIError.invalidURL
        }
        
        guard var components = URLComponents(string: base) else {
            #if DEBUG
            print("❌ Endpoint: Failed to create URLComponents from base: '\(base)'")
            #endif
            throw APIError.invalidURL
        }
        
        components.path = path
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        customHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }
}
