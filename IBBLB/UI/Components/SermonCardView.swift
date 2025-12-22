import SwiftUI

struct SermonCardView: View {
    let sermon: Sermon
    
    // Platform detection
    private var isTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailView

            VStack(alignment: .leading, spacing: isTV ? 8 : 4) {
                Text(sermon.title)
                    .font(isTV ? .system(size: 28, weight: .semibold) : .headline)
                    .lineLimit(isTV ? 3 : 2)
                    .foregroundColor(.primary)

                HStack(spacing: isTV ? 8 : 4) {
                    if let speaker = sermon.speaker, !speaker.isEmpty {
                        Text(speaker)
                    }

                    if let speaker = sermon.speaker, !speaker.isEmpty, sermon.date != nil {
                        Text("•")
                    }

                    if let date = sermon.date {
                        Text(date.formattedSermonDate)
                    }
                }
                .font(isTV ? .system(size: 22) : .subheadline)
                .foregroundColor(.secondary)
            }
            .padding(isTV ? 24 : 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: isTV ? 20 : 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: isTV ? 8 : 4, x: 0, y: 2)
    }

    private var thumbnailView: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                if let urlString = sermon.thumbnailUrl,
                   !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            loadingContent
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            placeholderContent
                        @unknown default:
                            placeholderContent
                        }
                    }
                } else {
                    placeholderContent
                }
            }
            .overlay {
                // Play overlay icon
                if let id = sermon.youtubeVideoId, !id.trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: isTV ? 80 : 44))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: isTV ? 12 : 8, x: 0, y: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
    }

    private var loadingContent: some View {
        ZStack {
            Color(.systemGray5)
            ProgressView()
                .tint(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderContent: some View {
        ZStack {
            Color(.systemGray6)
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: isTV ? 80 : 40))
                .foregroundColor(Color(.systemGray3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SermonCardView(sermon: Sermon(
        id: "1",
        title: "The Prodigal Son Returns",
        speaker: "Pastor John Doe",
        date: Date(),
        thumbnailUrl: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        youtubeVideoId: "dQw4w9WgXcQ",
        audioUrl: nil,
        tags: ["Parables", "Grace"]
    ))
    .padding()
}
