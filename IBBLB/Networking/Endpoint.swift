import Foundation

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
        
        #if DEBUG
        print("🔧 Endpoint: Building request")
        print("   Base URL: \(base.isEmpty ? "(empty)" : base)")
        print("   Path: \(path)")
        print("   Using override: \(baseURLOverride != nil ? "YES" : "NO")")
        #endif
        
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
            #if DEBUG
            print("❌ Endpoint: Failed to create URL from components")
            print("   Base: \(base)")
            print("   Path: \(path)")
            print("   Query items: \(queryItems?.count ?? 0)")
            #endif
            throw APIError.invalidURL
        }
        
        #if DEBUG
        print("✅ Endpoint: Final URL: \(url.absoluteString)")
        #endif
        
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
