import Foundation
import SwiftUI
#if canImport(Combine)
import Combine
#endif

@MainActor
class LiveViewModel: ObservableObject {
    @Published var status: LivestreamStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var timeRemaining: TimeInterval?

    private let apiService: MobileAPIService
    #if canImport(Combine)
    private var timer: AnyCancellable?
    #endif
    private var hasLoadedInitial = false
    private var isVisible = false
    private var cachedStartsAt: Date?

    init(apiService: MobileAPIService = MobileAPIService()) {
        self.apiService = apiService
    }

    /// Load initial data only once
    func loadInitial() async {
        guard !hasLoadedInitial else { return }
        hasLoadedInitial = true
        await fetchLivestream()
    }

    /// Force refresh (pull-to-refresh)
    func refresh() async {
        await fetchLivestream()
    }

    /// Called when view appears - resumes timer if needed
    func onAppear() {
        isVisible = true
        // Recalculate time remaining immediately (may have changed while off-screen)
        if let startsAt = cachedStartsAt {
            let remaining = startsAt.timeIntervalSince(Date())
            timeRemaining = remaining > 0 ? remaining : 0
        }
        // Resume timer if we have an upcoming event
        if status?.state == .upcoming && cachedStartsAt != nil {
            setupTimer()
        }
    }

    /// Called when view disappears - pauses timer to save CPU
    func onDisappear() {
        isVisible = false
        #if canImport(Combine)
        timer?.cancel()
        timer = nil
        #endif
    }

    private func fetchLivestream() async {
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
                isLoading = false
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
        #if canImport(Combine)
        timer?.cancel()
        #endif

        guard let startsAt = status?.event?.startsAt, status?.state == .upcoming else {
            print("🕒 Timer skipped: Condition not met.")
            cachedStartsAt = nil
            timeRemaining = nil
            return
        }

        // Cache startsAt for resuming timer after view reappears
        cachedStartsAt = startsAt

        // Calculate initial time remaining
        let now = Date()
        let initialRemaining = startsAt.timeIntervalSince(now)
        timeRemaining = initialRemaining > 0 ? initialRemaining : 0
        print("🕒 Initial time remaining: \(timeRemaining ?? -1)")

        // Don't start timer if view is not visible (saves CPU when on other tabs)
        guard isVisible else {
            print("🕒 Timer deferred: View not visible")
            return
        }

        #if canImport(Combine)
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self = self,
                      let startsAt = self.cachedStartsAt,
                      !self.isLoading else { return }

                let remaining = startsAt.timeIntervalSince(now)
                self.timeRemaining = remaining > 0 ? remaining : 0

                // If it just finished, trigger a one-time refresh
                if remaining <= 0 {
                    print("🕒 Timer expired. Refreshing...")
                    self.timer?.cancel()
                    self.cachedStartsAt = nil
                    Task {
                        await self.refresh()
                    }
                }
            }
        #endif
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
