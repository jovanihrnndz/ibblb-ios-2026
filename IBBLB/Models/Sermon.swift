import Foundation

struct Sermon: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let speaker: String?
    let date: Date?
    let thumbnailUrl: String?
    let youtubeVideoId: String?
    let audioUrl: String?
    let tags: [String]?
    let slug: String?

    // CodingKeys can be omitted since we use .convertFromSnakeCase in APIClient
    // but kept for explicit mapping or documentation if needed.
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case speaker
        case date
        case thumbnailUrl
        case youtubeVideoId = "youtubeId"
        case audioUrl
        case tags
        case slug
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Sermon, rhs: Sermon) -> Bool {
        lhs.id == rhs.id
    }
}
