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
    let playlistId: String?

    // Custom init to provide default for playlistId (for backwards compatibility)
    init(
        id: String,
        title: String,
        speaker: String? = nil,
        date: Date? = nil,
        thumbnailUrl: String? = nil,
        youtubeVideoId: String? = nil,
        audioUrl: String? = nil,
        tags: [String]? = nil,
        slug: String? = nil,
        playlistId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.speaker = speaker
        self.date = date
        self.thumbnailUrl = thumbnailUrl
        self.youtubeVideoId = youtubeVideoId
        self.audioUrl = audioUrl
        self.tags = tags
        self.slug = slug
        self.playlistId = playlistId
    }

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
        case playlistId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Sermon, rhs: Sermon) -> Bool {
        lhs.id == rhs.id
    }
}
