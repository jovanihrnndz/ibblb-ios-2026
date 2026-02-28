import Foundation

public enum AndroidAppSessionStore {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let selectedTab = "android.selectedTab"
        static let launchCount = "android.launchCount"
        static let searchText = "android.sermons.searchText"
        static let cachedSermons = "android.sermons.cached"
        static let lastOpenedSermonID = "android.sermons.lastOpenedID"
        static let eventsSearchText = "android.events.searchText"
        static let cachedEvents = "android.events.cached"
        static let lastOpenedEventID = "android.events.lastOpenedID"
        static let cachedGivingPage = "android.giving.cachedPage"
        static let lastLifecycleEvent = "android.lifecycle.lastEvent"
        static let lastLifecycleTimestamp = "android.lifecycle.lastTimestamp"
    }

    static func loadSelectedTab() -> AndroidAppTab {
        guard let raw = defaults.string(forKey: Key.selectedTab),
              let tab = AndroidAppTab(rawValue: raw) else {
            return .sermons
        }
        return tab
    }

    static func saveSelectedTab(_ tab: AndroidAppTab) {
        defaults.set(tab.rawValue, forKey: Key.selectedTab)
    }

    static func loadLaunchCount() -> Int {
        defaults.integer(forKey: Key.launchCount)
    }

    static func saveLaunchCount(_ count: Int) {
        defaults.set(count, forKey: Key.launchCount)
    }

    static func loadSearchText() -> String {
        defaults.string(forKey: Key.searchText) ?? ""
    }

    static func saveSearchText(_ text: String) {
        defaults.set(text, forKey: Key.searchText)
    }

    static func loadCachedSermons() -> [SermonSummary] {
        guard let data = defaults.data(forKey: Key.cachedSermons) else {
            return []
        }
        let decoder = JSONDecoder()
        if let sermons = try? decoder.decode([SermonSummary].self, from: data) {
            return sermons
        }
        return []
    }

    static func saveCachedSermons(_ sermons: [SermonSummary]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(sermons) else {
            return
        }
        defaults.set(data, forKey: Key.cachedSermons)
    }

    static func loadLastOpenedSermonID() -> String? {
        defaults.string(forKey: Key.lastOpenedSermonID)
    }

    static func saveLastOpenedSermonID(_ id: String?) {
        defaults.set(id, forKey: Key.lastOpenedSermonID)
    }

    static func loadEventsSearchText() -> String {
        defaults.string(forKey: Key.eventsSearchText) ?? ""
    }

    static func saveEventsSearchText(_ text: String) {
        defaults.set(text, forKey: Key.eventsSearchText)
    }

    static func loadCachedEvents() -> [EventSummary] {
        guard let data = defaults.data(forKey: Key.cachedEvents) else {
            return []
        }
        let decoder = JSONDecoder()
        if let events = try? decoder.decode([EventSummary].self, from: data) {
            return events
        }
        return []
    }

    static func saveCachedEvents(_ events: [EventSummary]) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(events) else {
            return
        }
        defaults.set(data, forKey: Key.cachedEvents)
    }

    static func loadLastOpenedEventID() -> String? {
        defaults.string(forKey: Key.lastOpenedEventID)
    }

    static func saveLastOpenedEventID(_ id: String?) {
        defaults.set(id, forKey: Key.lastOpenedEventID)
    }

    static func loadCachedGivingPage() -> GivingPageModel? {
        guard let data = defaults.data(forKey: Key.cachedGivingPage) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(GivingPageModel.self, from: data)
    }

    static func saveCachedGivingPage(_ page: GivingPageModel?) {
        guard let page else {
            defaults.removeObject(forKey: Key.cachedGivingPage)
            return
        }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(page) else {
            return
        }
        defaults.set(data, forKey: Key.cachedGivingPage)
    }

    static func saveLifecycleEvent(_ event: String) {
        defaults.set(event, forKey: Key.lastLifecycleEvent)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastLifecycleTimestamp)
    }
}
