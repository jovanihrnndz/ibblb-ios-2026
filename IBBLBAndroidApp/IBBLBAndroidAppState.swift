enum AndroidAppTab: String, Hashable {
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

struct IBBLBAndroidAppState {
    var selectedTab: AndroidAppTab = .sermons
    private(set) var launchCount: Int = 0

    mutating func markLaunch() {
        launchCount += 1
    }
}
