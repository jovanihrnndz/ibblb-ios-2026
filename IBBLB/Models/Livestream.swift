import Foundation

enum LivestreamState: String, Decodable {
    case live
    case upcoming
    case offline
}

struct LivestreamEvent: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let youtubeVideoId: String?
    let startsAt: Date?
    let endsAt: Date?
    let thumbnailUrl: String?
}

struct LivestreamStatus: Decodable {
    let state: LivestreamState
    let event: LivestreamEvent?
    let lastEvent: LivestreamEvent?
}
