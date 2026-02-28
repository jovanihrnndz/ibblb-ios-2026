import SwiftUI

public struct IBBLBAppRootView: View {
    @State private var appState = IBBLBAndroidAppState()

    public init() {}

    private var tabSelection: Binding<AndroidAppTab> {
        Binding(
            get: { appState.selectedTab },
            set: { appState.selectTab($0) }
        )
    }

    public var body: some View {
        TabView(selection: tabSelection) {
            SermonsRootView()
                .tabItem { Text(AndroidAppTab.sermons.title) }
                .tag(AndroidAppTab.sermons)

            LiveRootView()
                .tabItem { Text(AndroidAppTab.live.title) }
                .tag(AndroidAppTab.live)

            EventsRootView()
                .tabItem { Text(AndroidAppTab.events.title) }
                .tag(AndroidAppTab.events)

            GivingRootView()
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

    public func onInit() {
        AndroidAppSessionStore.saveLifecycleEvent("init")
    }

    public func onLaunch() {
        AndroidAppSessionStore.saveLifecycleEvent("launch")
    }

    public func onResume() {
        AndroidAppSessionStore.saveLifecycleEvent("resume")
    }

    public func onPause() {
        AndroidAppSessionStore.saveLifecycleEvent("pause")
    }

    public func onStop() {
        AndroidAppSessionStore.saveLifecycleEvent("stop")
    }

    public func onDestroy() {
        AndroidAppSessionStore.saveLifecycleEvent("destroy")
    }

    public func onLowMemory() {
        AndroidAppSessionStore.saveLifecycleEvent("lowMemory")
    }
}
