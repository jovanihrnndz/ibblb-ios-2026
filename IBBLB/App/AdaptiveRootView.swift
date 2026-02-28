import SwiftUI

/// Root container that switches between iPhone (tabs) and iPad (sidebar) layouts.
/// Device idiom is checked first so iPhone Pro Max models (which can report .regular
/// horizontal size class) always get the native bottom-tab layout.
struct AdaptiveRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    /// True when iPhone, or when size class is compact/nil on other devices
    private var isCompact: Bool {
        isPhone || horizontalSizeClass == .compact || horizontalSizeClass == nil
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
