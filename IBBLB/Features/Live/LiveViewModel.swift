import Foundation
import SwiftUI
import Combine

@MainActor
class LiveViewModel: ObservableObject {
    @Published var status: LivestreamStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var timeRemaining: TimeInterval?
    
    private let apiService: MobileAPIService
    private var timer: AnyCancellable?
    
    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService
    }
    
    func refresh() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedStatus = try await apiService.fetchLivestream()
            self.status = fetchedStatus
        } catch {
            let nsError = error as NSError
            if (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) || error is CancellationError {
                // Silently handle cancellation
                return
            }
            
            print("⚠️ API error fetching livestream: \(error)")
            self.errorMessage = "No se pudo cargar la información del servicio."
        }
        
        isLoading = false
        setupTimer()
    }
    
    func setupTimer() {
        print("🕒 Setting up timer. State: \(status?.state.rawValue ?? "nil"), StartsAt: \(status?.event?.startsAt?.description ?? "nil")")
        timer?.cancel()
        
        guard let startsAt = status?.event?.startsAt, status?.state == .upcoming else {
            print("🕒 Timer skipped: Condition not met.")
            timeRemaining = nil
            return
        }
        
        // Calculate initial time remaining
        let now = Date()
        let initialRemaining = startsAt.timeIntervalSince(now)
        timeRemaining = initialRemaining > 0 ? initialRemaining : 0
        print("🕒 Initial time remaining: \(timeRemaining ?? -1)")
        
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self = self, 
                      let startsAt = self.status?.event?.startsAt,
                      !self.isLoading else { return }
                
                let remaining = startsAt.timeIntervalSince(now)
                self.timeRemaining = remaining > 0 ? remaining : 0
                
                // If it just finished, trigger a one-time refresh
                if remaining <= 0 {
                    print("🕒 Timer expired. Refreshing...")
                    self.timer?.cancel()
                    Task {
                        await self.refresh()
                    }
                }
            }
    }
    
    func formattedTimeRemaining() -> String {
        guard let timeRemaining = timeRemaining else { return "" }
        
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%01d", minutes, seconds)
        }
    }
}
