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
            .font(.system(size: isTV ? 80 : 44))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.35), radius: isTV ? 12 : 8, x: 0, y: 5)
    }
}

#if canImport(UIKit)
    #Preview {
        ZStack {
            Color.gray
            VideoThumbnailOverlay()
        }
        .aspectRatio(16/9, contentMode: .fit)
        .cornerRadius(12)
        .padding()
    }
#endif
