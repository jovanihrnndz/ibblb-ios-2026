import Foundation

struct SermonsViewModel {
    var sermons: [SermonSummary] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var hasLoadedInitial: Bool = false

    var filteredSermons: [SermonSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sermons }
        let normalizedQuery = query.lowercased()

        return sermons.filter { sermon in
            sermon.title.lowercased().contains(normalizedQuery) ||
            (sermon.speaker?.lowercased().contains(normalizedQuery) ?? false)
        }
    }

    mutating func clearSearch() {
        searchText = ""
    }

    mutating func loadSampleData() {
        sermons = SermonFixtures.sample
        errorMessage = nil
        hasLoadedInitial = true
    }
}
