import Foundation

struct SermonsEnvelope: Decodable {
    let sermons: [SermonSummary]
}

struct SermonSummary: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let speaker: String?
    let date: Date?
    let description: String?
    let thumbnailURLString: String?
    let youtubeVideoID: String?
    let audioURLString: String?
    let slug: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case speaker
        case date
        case description
        case thumbnailURLString = "thumbnail"
        case youtubeVideoID = "youtubeId"
        case audioURLString = "audioUrl"
        case slug
    }

    init(
        id: String,
        title: String,
        speaker: String? = nil,
        date: Date? = nil,
        description: String? = nil,
        thumbnailURLString: String? = nil,
        youtubeVideoID: String? = nil,
        audioURLString: String? = nil,
        slug: String? = nil
    ) {
        self.id = id
        self.title = title
        self.speaker = speaker
        self.date = date
        self.description = description
        self.thumbnailURLString = thumbnailURLString
        self.youtubeVideoID = youtubeVideoID
        self.audioURLString = audioURLString
        self.slug = slug
    }

    var detailModel: SermonDetailModel {
        SermonDetailModel(summary: self)
    }

    var dateText: String {
        guard let date else { return "Date unavailable" }
        return DateDisplayFormatters.sermonDate.string(from: date)
    }

    var descriptionText: String {
        guard let description, !description.isEmpty else {
            return "No description is available for this sermon yet."
        }
        return description
    }
}

struct SermonDetailModel: Identifiable, Hashable {
    let id: String
    let title: String
    let speaker: String?
    let date: Date?
    let description: String
    let thumbnailURLString: String?
    let youtubeVideoID: String?
    let audioURLString: String?
    let slug: String?

    init(summary: SermonSummary) {
        self.id = summary.id
        self.title = summary.title
        self.speaker = summary.speaker
        self.date = summary.date
        self.description = summary.descriptionText
        self.thumbnailURLString = summary.thumbnailURLString
        self.youtubeVideoID = summary.youtubeVideoID
        self.audioURLString = summary.audioURLString
        self.slug = summary.slug
    }

    var dateText: String {
        guard let date else { return "Date unavailable" }
        return DateDisplayFormatters.sermonDate.string(from: date)
    }
}

enum SermonFixtures {
    static let sample: [SermonSummary] = [
        SermonSummary(
            id: "sample-1",
            title: "Faith That Endures",
            speaker: "Pastor Luis Parada",
            date: DateDisplayFormatters.parseISO8601("2026-02-09T15:00:00+00:00"),
            description: "Sample sermon used when loading local fallback content on Android.",
            youtubeVideoID: "OcFgjkzezNU",
            audioURLString: "https://example.com/sample-audio-1.mp3"
        ),
        SermonSummary(
            id: "sample-2",
            title: "Grace and Redemption",
            speaker: "Pastor Luis Parada",
            date: DateDisplayFormatters.parseISO8601("2026-02-16T15:00:00+00:00"),
            description: "Second sample item to validate list and detail navigation.",
            youtubeVideoID: "on-uSOEZtOw",
            audioURLString: "https://example.com/sample-audio-2.mp3"
        ),
        SermonSummary(
            id: "sample-3",
            title: "Prayer in Daily Life",
            speaker: "Pastor Luis Parada",
            date: DateDisplayFormatters.parseISO8601("2026-02-23T15:00:00+00:00"),
            description: "Third sample item for offline smoke testing.",
            youtubeVideoID: "7_sBlfYZJ8g",
            audioURLString: "https://example.com/sample-audio-3.mp3"
        )
    ]
}

enum DateDisplayFormatters {
    static let sermonDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseISO8601(_ value: String) -> Date? {
        iso8601WithFractional.date(from: value) ?? iso8601.date(from: value)
    }
}
