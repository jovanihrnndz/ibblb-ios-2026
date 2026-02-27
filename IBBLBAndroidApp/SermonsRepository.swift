import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol SermonsRepository {
    func fetchSermons() async throws -> [SermonSummary]
}

enum SermonsRepositoryError: Error {
    case invalidResponse
    case badStatusCode(Int)
}

struct LiveSermonsRepository: SermonsRepository {
    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = URL(string: "https://ibblb-website.vercel.app/api/sermons")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func fetchSermons() async throws -> [SermonSummary] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SermonsRepositoryError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SermonsRepositoryError.badStatusCode(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self),
               let date = DateDisplayFormatters.parseISO8601(value) {
                return date
            }
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date value in sermons response."
            )
        }
        let envelope = try decoder.decode(SermonsEnvelope.self, from: data)
        return envelope.sermons
    }
}
