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
            self.events = fetchedEvents.sorted(by: { $0.startDate < $1.startDate })
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
}
