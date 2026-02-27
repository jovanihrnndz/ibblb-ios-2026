import SwiftUI

// MARK: - Main Outline Section View

struct SermonOutlineSectionView: View {
    let outline: SermonOutline

    @State private var selectedPoint: SelectedOutlinePoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Bosquejo")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            // Scripture Passage
            if let passage = outline.outlinePassage, !passage.isEmpty {
                Text(passage)
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
            }

            // Content Card
            VStack(alignment: .leading, spacing: 16) {
                if outline.hasStructuredOutline {
                    structuredOutlineContent
                } else if outline.hasLegacyOutline {
                    legacyOutlineContent
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .sheet(item: $selectedPoint) { selected in
            OutlinePointDetailSheetView(selectedPoint: selected)
        }
    }

    // MARK: - Structured Outline

    @ViewBuilder
    private var structuredOutlineContent: some View {
        // Introduction (compact, non-tappable)
        if let introduction = outline.outlineIntroduction, !introduction.isEmpty {
            OutlineSectionContent(
                title: "Introduccion",
                blocks: introduction
            )
        }

        // Main Points (compact list)
        if let points = outline.outlinePoints, !points.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Puntos principales")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    OutlinePointRowView(
                        point: point,
                        number: index + 1,
                        onTap: {
                            selectedPoint = SelectedOutlinePoint(point: point, number: index + 1)
                        }
                    )
                }
            }
        }

        // Conclusion (compact, non-tappable)
        if let conclusion = outline.outlineConclusion, !conclusion.isEmpty {
            OutlineSectionContent(
                title: "Conclusion",
                blocks: conclusion
            )
        }
    }

    // MARK: - Legacy Outline

    @ViewBuilder
    private var legacyOutlineContent: some View {
        if let blocks = outline.outline {
            PortableTextView(blocks: blocks)
        }
    }
}

// MARK: - Outline Point Row View (Compact List Item)

private struct OutlinePointRowView: View {
    let point: SermonOutlinePoint
    let number: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Number Badge
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.accentColor))

                // Title and Preview
                VStack(alignment: .leading, spacing: 3) {
                    Text(point.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Optional 1-line preview
                    if let preview = firstSentencePreview {
                        Text(preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // Extract first sentence from body for preview
    private var firstSentencePreview: String? {
        guard let body = point.body, !body.isEmpty else { return nil }

        // Get plain text from first block
        let plainText = body.first?.plainText ?? ""
        guard !plainText.isEmpty else { return nil }

        // Extract first sentence (up to first period, exclamation, or question mark)
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        if let range = plainText.rangeOfCharacter(from: sentenceEnders) {
            let firstSentence = String(plainText[..<range.upperBound])
            return firstSentence.trimmingCharacters(in: .whitespaces)
        }

        // If no sentence ender found, return truncated text
        if plainText.count > 60 {
            let index = plainText.index(plainText.startIndex, offsetBy: 60)
            return String(plainText[..<index]) + "..."
        }

        return plainText
    }
}

// MARK: - Outline Section Content (Introduction/Conclusion)

private struct OutlineSectionContent: View {
    let title: String
    let blocks: [PortableTextBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            PortableTextView(blocks: blocks)
        }
    }
}

// MARK: - Portable Text Rendering

struct PortableTextView: View {
    let blocks: [PortableTextBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                PortableTextBlockView(block: block)
            }
        }
    }
}

private struct PortableTextBlockView: View {
    let block: PortableTextBlock

    var body: some View {
        if block.type == "block" {
            textContent
        }
    }

    @ViewBuilder
    private var textContent: some View {
        let style = block.style ?? "normal"

        switch style {
        case "h1":
            attributedText
                .font(.title)
                .fontWeight(.bold)
        case "h2":
            attributedText
                .font(.title2)
                .fontWeight(.semibold)
        case "h3":
            attributedText
                .font(.title3)
                .fontWeight(.semibold)
        case "h4":
            attributedText
                .font(.headline)
        case "blockquote":
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                attributedText
                    .italic()
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        default:
            attributedText
                .font(.body)
        }
    }

    private var attributedText: Text {
        guard let children = block.children else {
            return Text("")
        }

        #if canImport(UIKit)
        var result = AttributedString()
        for span in children {
            var attributed = AttributedString(span.text)
            if span.isBold {
                attributed.font = Font.body.bold()
            }
            if span.isItalic {
                attributed.font = (attributed.font ?? Font.body).italic()
            }
            if span.isUnderlined {
                attributed.underlineStyle = Text.LineStyle(pattern: .solid)
            }
            result.append(attributed)
        }
        return Text(result)
        #else
        return Text(children.map { $0.text }.joined())
        #endif
    }
}

// MARK: - Preview

#if canImport(UIKit)
    #Preview("Structured Outline - Compact List") {
        ScrollView {
            SermonOutlineSectionView(outline: SermonOutline(
                id: "preview-1",
                title: "Sample Sermon",
                youtubeId: "abc123",
                slug: "sample-sermon",
                notesUrl: nil,
                scriptureReferences: nil,
                outline: nil,
                outlineTitle: "El Amor de Dios",
                outlinePassage: "Juan 3:16",
                outlineIntroduction: [
                    PortableTextBlock(
                        type: "block",
                        style: "normal",
                        children: [
                            PortableTextSpan(type: "span", text: "El amor de Dios es ", marks: nil),
                            PortableTextSpan(type: "span", text: "incondicional", marks: ["strong"]),
                            PortableTextSpan(type: "span", text: " y eterno.", marks: nil)
                        ],
                        markDefs: nil
                    )
                ],
                outlinePoints: [
                    SermonOutlinePoint(
                        title: "El amor de Dios es sacrificial",
                        scripture: "Juan 3:16",
                        body: [
                            PortableTextBlock(
                                type: "block",
                                style: "normal",
                                children: [
                                    PortableTextSpan(type: "span", text: "Dios dio a su unico Hijo por nosotros. Este es el mayor acto de amor.", marks: nil)
                                ],
                                markDefs: nil
                            )
                        ]
                    ),
                    SermonOutlinePoint(
                        title: "El amor de Dios es redentor y transformador",
                        scripture: "Romanos 5:8",
                        body: [
                            PortableTextBlock(
                                type: "block",
                                style: "normal",
                                children: [
                                    PortableTextSpan(type: "span", text: "Cristo murio por nosotros siendo ", marks: nil),
                                    PortableTextSpan(type: "span", text: "pecadores", marks: ["em"]),
                                    PortableTextSpan(type: "span", text: ".", marks: nil)
                                ],
                                markDefs: nil
                            )
                        ]
                    ),
                    SermonOutlinePoint(
                        title: "El amor de Dios es eterno",
                        scripture: "Jeremias 31:3",
                        body: nil
                    )
                ],
                outlineConclusion: [
                    PortableTextBlock(
                        type: "block",
                        style: "normal",
                        children: [
                            PortableTextSpan(type: "span", text: "Aceptemos el amor de Dios hoy.", marks: ["strong"])
                        ],
                        markDefs: nil
                    )
                ]
            ))
            .padding()
        }
    }
#endif
