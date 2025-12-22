import Foundation

// MARK: - Portable Text Models (Sanity Block Format)

/// A span of text within a Portable Text block
struct PortableTextSpan: Decodable {
    let type: String
    let text: String
    let marks: [String]?

    enum CodingKeys: String, CodingKey {
        case type = "_type"
        case text
        case marks
    }

    var isBold: Bool {
        marks?.contains("strong") ?? false
    }

    var isItalic: Bool {
        marks?.contains("em") ?? false
    }

    var isUnderlined: Bool {
        marks?.contains("underline") ?? false
    }
}

/// A block of content in Portable Text format
struct PortableTextBlock: Decodable {
    let type: String
    let style: String?
    let children: [PortableTextSpan]?
    let markDefs: [AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case type = "_type"
        case style
        case children
        case markDefs
    }

    /// Extract plain text from the block
    var plainText: String {
        children?.map { $0.text }.joined() ?? ""
    }
}

// MARK: - Sermon Outline Models (Matches Sanity Schema)

/// A main point in the sermon outline
struct SermonOutlinePoint: Decodable {
    let title: String
    let scripture: String?
    let body: [PortableTextBlock]?

    /// Extract plain text from body blocks
    var bodyPlainText: String {
        body?.map { $0.plainText }.joined(separator: "\n") ?? ""
    }
}

/// The complete sermon outline from Sanity CMS
struct SermonOutline: Decodable {
    let id: String
    let title: String?
    let youtubeId: String?
    let slug: String?
    let notesUrl: String?
    let scriptureReferences: [String]?

    // Legacy outline (Portable Text)
    let outline: [PortableTextBlock]?

    // Structured outline fields
    let outlineTitle: String?
    let outlinePassage: String?
    let outlineIntroduction: [PortableTextBlock]?
    let outlinePoints: [SermonOutlinePoint]?
    let outlineConclusion: [PortableTextBlock]?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case youtubeId
        case slug
        case notesUrl
        case scriptureReferences
        case outline
        case outlineTitle
        case outlinePassage
        case outlineIntroduction
        case outlinePoints
        case outlineConclusion
    }

    /// Check if structured outline has content
    var hasStructuredOutline: Bool {
        outlineTitle != nil ||
        outlinePassage != nil ||
        outlineIntroduction?.isEmpty == false ||
        outlinePoints?.isEmpty == false ||
        outlineConclusion?.isEmpty == false
    }

    /// Check if legacy outline has content
    var hasLegacyOutline: Bool {
        outline?.isEmpty == false
    }

    /// Check if any outline content exists
    var hasContent: Bool {
        hasStructuredOutline || hasLegacyOutline
    }
}
