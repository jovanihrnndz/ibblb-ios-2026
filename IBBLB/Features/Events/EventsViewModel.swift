import Foundation
import SwiftUI
import Combine

@MainActor
class EventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService: MobileAPIService
    
    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService
    }
    
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedEvents = try await apiService.fetchEvents()
            let upcomingEvents = filterUpcomingEvents(fetchedEvents)
            self.events = upcomingEvents.sorted(by: { $0.startDate < $1.startDate })
        } catch {
            let nsError = error as NSError
            if (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) || error is CancellationError {
                // Silently handle cancellation
                return
            }
            
            print("⚠️ API error fetching events: \(error)")
            self.errorMessage = "No se pudieron cargar los eventos."
        }
        
        isLoading = false
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
