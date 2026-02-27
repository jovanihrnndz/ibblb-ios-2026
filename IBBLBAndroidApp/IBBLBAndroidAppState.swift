public enum AndroidAppTab: String, Hashable {
    case sermons
    case live
    case events
    case giving

    var title: String {
        switch self {
        case .sermons: return "Sermons"
        case .live: return "Live"
        case .events: return "Events"
        case .giving: return "Giving"
        }
    }
}

public struct IBBLBAndroidAppState {
    var selectedTab: AndroidAppTab
    private(set) var launchCount: Int

    init() {
        selectedTab = AndroidAppSessionStore.loadSelectedTab()
        launchCount = AndroidAppSessionStore.loadLaunchCount()
    }

    mutating func selectTab(_ tab: AndroidAppTab) {
        selectedTab = tab
        AndroidAppSessionStore.saveSelectedTab(tab)
    }

    mutating func markLaunch() {
        launchCount += 1
        AndroidAppSessionStore.saveLaunchCount(launchCount)
    }
}
