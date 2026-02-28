import Foundation

public struct GivingViewModel {
    var page: GivingPageModel?
    var isLoading = false
    var errorMessage: String?
    var hasLoadedInitial = false

    init() {
        page = AndroidAppSessionStore.loadCachedGivingPage()
    }

    mutating func replacePage(_ newPage: GivingPageModel) {
        page = newPage
        AndroidAppSessionStore.saveCachedGivingPage(newPage)
    }

    mutating func loadSampleData() {
        replacePage(GivingFixtures.sample)
        errorMessage = nil
        hasLoadedInitial = true
    }
}
