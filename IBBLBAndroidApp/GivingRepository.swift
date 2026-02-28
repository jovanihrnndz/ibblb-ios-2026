import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol GivingRepository {
    func fetchGivingPage() async throws -> GivingPageModel
}

public enum GivingRepositoryError: Error {
    case invalidResponse
    case badStatusCode(Int)
}

public struct LiveGivingRepository: GivingRepository {
    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = URL(string: "https://ibblb-website.vercel.app/api/giving")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    public func fetchGivingPage() async throws -> GivingPageModel {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GivingRepositoryError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GivingRepositoryError.badStatusCode(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GivingPageModel.self, from: data)
    }
}
