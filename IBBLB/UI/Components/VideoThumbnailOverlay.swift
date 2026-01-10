import SwiftUI

/// Shared overlay for video thumbnails - displays a centered play icon
/// Used in SermonCardView and PreviousServiceVideoCard for consistent styling
struct VideoThumbnailOverlay: View {
    // Platform detection
    private var isTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        Image(systemName: "play.circle.fill")
            .font(isTV ? .system(size: 80) : .system(size: 44)) // Large decorative play icon - size appropriate for thumbnail overlay
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.35), radius: isTV ? 12 : 8, x: 0, y: 5)
            .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.gray
        VideoThumbnailOverlay()
    }
    .aspectRatio(16/9, contentMode: .fit)
    .cornerRadius(12)
    .padding()
}
