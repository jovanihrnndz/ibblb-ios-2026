import Foundation

struct SermonsViewModel {
    var sermons: [SermonSummary]
    var searchText: String
    var isLoading: Bool = false
    var errorMessage: String?
    var hasLoadedInitial: Bool = false

    init() {
        sermons = AndroidAppSessionStore.loadCachedSermons()
        searchText = AndroidAppSessionStore.loadSearchText()
    }

    var filteredSermons: [SermonSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sermons }
        let normalizedQuery = query.lowercased()

        return sermons.filter { sermon in
            sermon.title.lowercased().contains(normalizedQuery) ||
            (sermon.speaker?.lowercased().contains(normalizedQuery) ?? false)
        }
    }

    mutating func updateSearchText(_ text: String) {
        searchText = text
        AndroidAppSessionStore.saveSearchText(text)
    }

    mutating func replaceSermons(_ items: [SermonSummary]) {
        sermons = items
        AndroidAppSessionStore.saveCachedSermons(items)
    }

    mutating func clearSearch() {
        updateSearchText("")
    }

    mutating func loadSampleData() {
        replaceSermons(SermonFixtures.sample)
        errorMessage = nil
        hasLoadedInitial = true
    }
}
