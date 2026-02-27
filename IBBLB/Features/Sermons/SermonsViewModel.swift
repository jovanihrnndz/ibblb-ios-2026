import Foundation
#if canImport(Combine)
import Combine
#endif

@MainActor
class SermonsViewModel: ObservableObject {
    @Published var sermons: [Sermon] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchText: String = ""
    @Published var selectedYear: Int? = nil

    private let apiService: MobileAPIService
    private let limit = 10
    private var currentOffset: Int = 0
    private var hasMore: Bool = true
    #if canImport(Combine)
    private var cancellables = Set<AnyCancellable>()
    #endif
    private var hasLoadedInitial = false
    private var lastSearchText: String = ""

    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService

        #if canImport(Combine)
        // Listen for search changes - only trigger after initial load and if text changed
        $searchText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newSearchText in
                guard let self = self,
                      self.hasLoadedInitial,
                      newSearchText != self.lastSearchText else { return }
                self.lastSearchText = newSearchText
                Task {
                    await self.fetchSermons(isLoadMore: false)
                }
            }
            .store(in: &cancellables)
        #endif
    }

    func loadInitial() async {
        guard !hasLoadedInitial else { return }
        hasLoadedInitial = true
        await fetchSermons()
    }

    func refresh() async {
        await fetchSermons(isLoadMore: false)
    }

    func setYearFilter(_ year: Int?) {
        selectedYear = year
        Task {
            await fetchSermons(isLoadMore: false)
        }
    }

    func clearSearch() {
        searchText = ""
        lastSearchText = ""
    }

    func loadMoreIfNeeded(currentItem: Sermon) {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        let threshold = max(0, sermons.count - 3)
        guard let currentIndex = sermons.firstIndex(where: { $0.id == currentItem.id }),
              currentIndex >= threshold else { return }
        Task { await fetchSermons(isLoadMore: true) }
    }

    private var fetchTask: Task<Void, Never>?

    private func fetchSermons(isLoadMore: Bool = false) async {
        if isLoadMore {
            guard !isLoading, !isLoadingMore, hasMore else { return }
            isLoadingMore = true
        } else {
            // Cancel any in-flight operation and reset all state
            fetchTask?.cancel()
            isLoading = false
            isLoadingMore = false
            currentOffset = 0
            hasMore = true
            isLoading = true
            errorMessage = nil
        }

        let taskOffset = currentOffset

        fetchTask = Task { @MainActor in
            do {
                let fetchedSermons = try await apiService.fetchSermons(
                    limit: limit,
                    offset: taskOffset,
                    search: searchText.isEmpty ? nil : searchText,
                    tag: nil,
                    year: selectedYear
                )

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                if isLoadMore {
                    self.sermons.append(contentsOf: fetchedSermons)
                } else {
                    self.sermons = fetchedSermons
                }
                self.currentOffset += fetchedSermons.count
                self.hasMore = fetchedSermons.count >= self.limit

                #if DEBUG
                print("✅ Sermons loaded: \(fetchedSermons.count) items (offset: \(taskOffset), loadMore: \(isLoadMore))")
                #endif
            } catch {
                // Check for cancellation errors first - these are expected and should be silent
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    return
                }
                if error is CancellationError {
                    return
                }

                print("❌ API Error (Sermons): \(error)")
                if !isLoadMore {
                    self.errorMessage = "No se pudieron cargar los sermones. Inténtalo de nuevo."
                }
            }

            // Only update loading state if task wasn't cancelled
            if !Task.isCancelled {
                if isLoadMore {
                    self.isLoadingMore = false
                } else {
                    self.isLoading = false
                }
            }
        }

        await fetchTask?.value
    }
}
