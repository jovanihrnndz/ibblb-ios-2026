import Foundation
import SwiftUI
import Combine

@MainActor
class EventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: MobileAPIService
    private var fetchTask: Task<Void, Never>?
    
    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService
    }
    
    func refresh() async {
        // Cancel previous task to prevent race conditions
        fetchTask?.cancel()
        
        fetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            isLoading = true
            errorMessage = nil

            do {
                let fetchedEvents = try await apiService.fetchEvents()
                guard !Task.isCancelled else { return }
                let upcomingEvents = filterUpcomingEvents(fetchedEvents)
                self.events = upcomingEvents.sorted(by: { $0.startDate < $1.startDate })
            } catch {
                // Handle cancellation silently
                if error is CancellationError {
                    return
                }
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    return
                }
                
                // Only show errors for actual failures
                print("⚠️ API error fetching events: \(error)")
                self.errorMessage = String(localized: "Unable to load events.")
            }
            
            // Only update loading state if task wasn't cancelled
            if !Task.isCancelled {
                isLoading = false
            }
        }
        
        await fetchTask?.value
    }

    /// Filters events to only include upcoming ones.
    /// Uses endDate for multi-day events, or startDate if no endDate exists.
    /// Events happening today are included.
    private func filterUpcomingEvents(_ events: [Event]) -> [Event] {
        let startOfToday = Calendar.current.startOfDay(for: Date())

        return events.filter { event in
            // Use endDate if available (for multi-day events), otherwise use startDate
            let relevantDate = event.endDate ?? event.startDate
            return relevantDate >= startOfToday
        }
    }
}
