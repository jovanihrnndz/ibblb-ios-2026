import SwiftUI

/// Root container that switches between iPhone (tabs) and iPad (sidebar) layouts
/// based on horizontal size class. Supports split-screen and Stage Manager.
struct AdaptiveRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Defaults to compact when size class is nil (e.g., during early layout)
    private var isCompact: Bool {
        horizontalSizeClass == .compact || horizontalSizeClass == nil
    }

    var body: some View {
        if isCompact {
            AppRootView()
        } else {
            iPadRootView()
        }
    }
}

#if canImport(UIKit)
#Preview("iPhone") {
    AdaptiveRootView()
        .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad") {
    AdaptiveRootView()
        .environment(\.horizontalSizeClass, .regular)
}
#endif
