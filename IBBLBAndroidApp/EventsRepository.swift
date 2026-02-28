import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol EventsRepository {
    func fetchEvents() async throws -> [EventSummary]
}

public enum EventsRepositoryError: Error {
    case invalidResponse
    case badStatusCode(Int)
    case invalidURL
}

public struct SanityEventsRepository: EventsRepository {
    private let endpoint: URL
    private let session: URLSession

    init(
        projectID: String = "bck48elw",
        dataset: String = "production",
        session: URLSession = .shared
    ) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(projectID).api.sanity.io"
        components.path = "/v2021-03-25/data/query/\(dataset)"
        components.queryItems = [URLQueryItem(name: "query", value: Self.eventsQuery)]
        endpoint = components.url ?? URL(string: "https://\(projectID).api.sanity.io/v2021-03-25/data/query/\(dataset)")!
        self.session = session
    }

    public func fetchEvents() async throws -> [EventSummary] {
        guard endpoint.absoluteString.hasPrefix("https://") else {
            throw EventsRepositoryError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EventsRepositoryError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw EventsRepositoryError.badStatusCode(httpResponse.statusCode)
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
                debugDescription: "Unsupported date value in events response."
            )
        }

        let envelope = try decoder.decode(EventsEnvelope.self, from: data)
        return envelope.result
    }

    private static let eventsQuery = """
    *[_type == "event" && !(_id in path("drafts.**"))] {
      _id,
      title,
      "imageUrl": image.asset->url,
      startDate,
      endDate,
      description,
      location,
      registrationEnabled
    } | order(startDate asc)
    """
}
