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
            return "The URL is invalid."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "The server returned an invalid response."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let statusCode):
            return "Server responded with status code: \(statusCode)"
        case .unauthorized:
            return "Unauthorized access. Please check your token."
        }
    }
}
