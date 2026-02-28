import Foundation

public struct EventsEnvelope: Decodable {
    let result: [EventSummary]
}

public struct EventSummary: Codable, Identifiable, Hashable {
    public let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let imageURLString: String?
    let description: String?
    let registrationEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case startDate
        case endDate
        case location
        case imageURLString = "imageUrl"
        case description
        case registrationEnabled
    }

    init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        location: String? = nil,
        imageURLString: String? = nil,
        description: String? = nil,
        registrationEnabled: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.imageURLString = imageURLString
        self.description = description
        self.registrationEnabled = registrationEnabled
    }

    var detailModel: EventDetailModel {
        EventDetailModel(summary: self)
    }

    var dateText: String {
        if let endDate {
            return "\(EventDateFormatters.mediumDateTime.string(from: startDate)) - \(EventDateFormatters.mediumDateTime.string(from: endDate))"
        }
        return EventDateFormatters.mediumDateTime.string(from: startDate)
    }

    var descriptionText: String {
        guard let description, !description.isEmpty else {
            return "No details are available for this event yet."
        }
        return description
    }
}

public struct EventDetailModel: Identifiable, Hashable {
    public let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let location: String?
    let imageURLString: String?
    let description: String
    let registrationEnabled: Bool

    init(summary: EventSummary) {
        id = summary.id
        title = summary.title
        startDate = summary.startDate
        endDate = summary.endDate
        location = summary.location
        imageURLString = summary.imageURLString
        description = summary.descriptionText
        registrationEnabled = summary.registrationEnabled ?? false
    }

    var dateText: String {
        if let endDate {
            return "\(EventDateFormatters.mediumDateTime.string(from: startDate)) - \(EventDateFormatters.mediumDateTime.string(from: endDate))"
        }
        return EventDateFormatters.mediumDateTime.string(from: startDate)
    }
}

public enum EventFixtures {
    static let sample: [EventSummary] = [
        EventSummary(
            id: "event-sample-1",
            title: "Community Prayer Night",
            startDate: DateDisplayFormatters.parseISO8601("2026-03-06T02:30:00+00:00") ?? .now,
            location: "Main Sanctuary",
            description: "Join us for worship and prayer as a church family.",
            registrationEnabled: false
        ),
        EventSummary(
            id: "event-sample-2",
            title: "Family Fellowship Lunch",
            startDate: DateDisplayFormatters.parseISO8601("2026-03-15T20:00:00+00:00") ?? .now,
            location: "Church Hall",
            description: "A casual fellowship lunch for all families and visitors.",
            registrationEnabled: true
        ),
        EventSummary(
            id: "event-sample-3",
            title: "Youth Bible Workshop",
            startDate: DateDisplayFormatters.parseISO8601("2026-03-21T01:00:00+00:00") ?? .now,
            location: "Youth Room",
            description: "Interactive Bible study and leadership development for youth.",
            registrationEnabled: true
        )
    ]
}

public enum EventDateFormatters {
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
