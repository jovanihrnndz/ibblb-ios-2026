import SwiftUI

// MARK: - Selected Outline Point (Identifiable wrapper for sheet)

struct SelectedOutlinePoint: Identifiable {
    let id = UUID()
    let point: SermonOutlinePoint
    let number: Int
}

// MARK: - Outline Point Detail Sheet View

struct OutlinePointDetailSheetView: View {
    let selectedPoint: SelectedOutlinePoint
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Point Header
                    headerSection

                    // Body Content
                    bodySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            #if canImport(UIKit)
                            .symbolRenderingMode(.hierarchical)
                            #endif
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        #if canImport(UIKit)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Number Badge
            Text("Punto \(selectedPoint.number)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .textCase(.uppercase)
                .tracking(0.5)

            // Point Title
            Text(selectedPoint.point.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                #if canImport(UIKit)
                .fixedSize(horizontal: false, vertical: true)
                #endif

            // Scripture Reference
            if let scripture = selectedPoint.point.scripture, !scripture.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "book.closed.fill")
                        .font(.caption)
                    Text(scripture)
                        .font(.subheadline)
                        .italic()
                }
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Body Section

    @ViewBuilder
    private var bodySection: some View {
        if let body = selectedPoint.point.body, !body.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(body.enumerated()), id: \.offset) { _, block in
                    ReadableBlockView(block: block)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        } else {
            // No body content placeholder
            VStack(spacing: 12) {
                Image(systemName: "text.page")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Sin notas")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

// MARK: - Readable Block View (Optimized for reading)

private struct ReadableBlockView: View {
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
                .font(.title2)
                .fontWeight(.bold)
        case "h2":
            attributedText
                .font(.title3)
                .fontWeight(.semibold)
        case "h3":
            attributedText
                .font(.headline)
        case "h4":
            attributedText
                .font(.subheadline)
                .fontWeight(.semibold)
        case "blockquote":
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                attributedText
                    .font(.body)
                    .italic()
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        default:
            attributedText
                .font(.body)
                .lineSpacing(6)
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
        // Android: render as plain concatenated text
        return Text(children.map { $0.text }.joined())
        #endif
    }
}

// MARK: - Preview

#if canImport(UIKit)
    #Preview("Point with Content") {
        OutlinePointDetailSheetView(
            selectedPoint: SelectedOutlinePoint(
                point: SermonOutlinePoint(
                    title: "El amor de Dios es sacrificial y transformador",
                    scripture: "Juan 3:16",
                    body: [
                        PortableTextBlock(
                            type: "block",
                            style: "normal",
                            children: [
                                PortableTextSpan(type: "span", text: "Dios dio a su unico Hijo por nosotros. Este es el amor mas grande que existe.", marks: nil)
                            ],
                            markDefs: nil
                        ),
                        PortableTextBlock(
                            type: "block",
                            style: "normal",
                            children: [
                                PortableTextSpan(type: "span", text: "El sacrificio de Cristo ", marks: nil),
                                PortableTextSpan(type: "span", text: "demuestra", marks: ["strong"]),
                                PortableTextSpan(type: "span", text: " el amor incondicional de Dios hacia la humanidad.", marks: nil)
                            ],
                            markDefs: nil
                        )
                    ]
                ),
                number: 1
            )
        )
    }

    #Preview("Point without Content") {
        OutlinePointDetailSheetView(
            selectedPoint: SelectedOutlinePoint(
                point: SermonOutlinePoint(
                    title: "Punto sin notas detalladas",
                    scripture: "Romanos 8:28",
                    body: nil
                ),
                number: 2
            )
        )
    }
#endif
