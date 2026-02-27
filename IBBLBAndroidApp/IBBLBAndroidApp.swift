import SwiftUI

public struct IBBLBAppRootView: View {
    @State private var appState = IBBLBAndroidAppState()

    public init() {}

    public var body: some View {
        TabView(selection: $appState.selectedTab) {
            SermonsRootView()
                .tabItem { Text(AndroidAppTab.sermons.title) }
                .tag(AndroidAppTab.sermons)

            FeaturePlaceholderView(
                title: AndroidAppTab.live.title,
                message: "Live tab is staged for the next Android milestone."
            )
            .tabItem { Text(AndroidAppTab.live.title) }
            .tag(AndroidAppTab.live)

            FeaturePlaceholderView(
                title: AndroidAppTab.events.title,
                message: "Events tab is staged for the next Android milestone."
            )
            .tabItem { Text(AndroidAppTab.events.title) }
            .tag(AndroidAppTab.events)

            FeaturePlaceholderView(
                title: AndroidAppTab.giving.title,
                message: "Giving tab is staged for the next Android milestone."
            )
            .tabItem { Text(AndroidAppTab.giving.title) }
            .tag(AndroidAppTab.giving)
        }
        .onAppear {
            if appState.launchCount == 0 {
                appState.markLaunch()
            }
        }
    }
}

public final class IBBLBAndroidAppDelegate: Sendable {
    public static let shared = IBBLBAndroidAppDelegate()

    private init() {}

    public func onInit() {}
    public func onLaunch() {}
    public func onResume() {}
    public func onPause() {}
    public func onStop() {}
    public func onDestroy() {}
    public func onLowMemory() {}
}
