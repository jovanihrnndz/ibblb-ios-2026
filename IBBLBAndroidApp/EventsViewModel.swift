import Foundation

public struct EventsViewModel {
    var events: [EventSummary]
    var searchText: String
    var isLoading: Bool = false
    var errorMessage: String?
    var hasLoadedInitial: Bool = false

    init() {
        events = AndroidAppSessionStore.loadCachedEvents()
        searchText = AndroidAppSessionStore.loadEventsSearchText()
    }

    var filteredEvents: [EventSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return events }
        let normalizedQuery = query.lowercased()

        return events.filter { event in
            event.title.lowercased().contains(normalizedQuery) ||
            (event.location?.lowercased().contains(normalizedQuery) ?? false)
        }
    }

    mutating func updateSearchText(_ text: String) {
        searchText = text
        AndroidAppSessionStore.saveEventsSearchText(text)
    }

    mutating func replaceEvents(_ items: [EventSummary]) {
        events = items
        AndroidAppSessionStore.saveCachedEvents(items)
    }

    mutating func clearSearch() {
        updateSearchText("")
    }

    mutating func loadSampleData() {
        replaceEvents(EventFixtures.sample)
        errorMessage = nil
        hasLoadedInitial = true
    }

    mutating func replaceWithUpcoming(_ items: [EventSummary], now: Date = Date()) {
        let upcoming = items.filter { event in
            let relevant = event.endDate ?? event.startDate
            return relevant >= Calendar.current.startOfDay(for: now)
        }
        replaceEvents(upcoming.sorted(by: { $0.startDate < $1.startDate }))
    }
}
