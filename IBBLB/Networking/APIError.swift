import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(statusCode: Int)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "The URL is invalid.")
        case .requestFailed(let error):
            return String(localized: "Request failed: \(error.localizedDescription)")
        case .invalidResponse:
            return String(localized: "The server returned an invalid response.")
        case .decodingError(let error):
            return String(localized: "Failed to decode response: \(error.localizedDescription)")
        case .serverError(let statusCode):
            return String(localized: "Server responded with status code: \(statusCode)")
        case .unauthorized:
            return String(localized: "Unauthorized access. Please check your token.")
        }
    }
}
