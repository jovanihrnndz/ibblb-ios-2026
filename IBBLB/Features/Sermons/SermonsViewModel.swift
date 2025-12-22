import Foundation
import Combine

@MainActor
class SermonsViewModel: ObservableObject {
    @Published var sermons: [Sermon] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchText: String = ""
    
    private let apiService: MobileAPIService
    private let limit = 20
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedInitial = false
    private var lastSearchText: String = ""
    
    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService
        
        // Listen for search changes - only trigger if text actually changed
        $searchText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newSearchText in
                guard let self = self else { return }
                // Only fetch if search text actually changed
                if newSearchText != self.lastSearchText {
                    self.lastSearchText = newSearchText
                    Task {
                        await self.fetchSermons()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func loadInitial() async {
        // Only load once
        guard !hasLoadedInitial && sermons.isEmpty else { return }
        hasLoadedInitial = true
        await fetchSermons()
    }
    
    func refresh() async {
        await fetchSermons()
    }
    
    func clearSearch() {
        searchText = ""
        lastSearchText = ""
    }
    
    private var fetchTask: Task<Void, Never>?
    
    private func fetchSermons() async {
        // Cancel any existing fetch task to prevent duplicate requests
        fetchTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        fetchTask = Task { @MainActor in
            do {
                let fetchedSermons = try await apiService.fetchSermons(
                    limit: limit,
                    offset: 0,
                    search: searchText.isEmpty ? nil : searchText
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                self.sermons = fetchedSermons
                #if DEBUG
                print("✅ Sermons loaded: \(fetchedSermons.count) items")
                #endif
            } catch {
                // Check for cancellation errors first - these are expected and should be silent
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    // Silently handle cancellation - this is expected when cancelling previous requests
                    return
                }
                if error is CancellationError {
                    // Silently handle Swift cancellation
                    return
                }
                
                // Only log and show errors for actual failures
                print("❌ API Error (Sermons): \(error)")
                self.errorMessage = "No se pudieron cargar los sermones. Inténtalo de nuevo."
            }
            
            // Only update loading state if task wasn't cancelled
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
        
        await fetchTask?.value
    }
}
