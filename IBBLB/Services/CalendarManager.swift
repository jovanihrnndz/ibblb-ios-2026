import EventKit
import Foundation

@MainActor
final class CalendarManager {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()

    private init() {}

    enum CalendarError: LocalizedError {
        case accessDenied
        case accessRestricted
        case saveFailed(Error)
        case unknown

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return String(localized: "Calendar access denied. Please enable access in Settings.")
            case .accessRestricted:
                return String(localized: "Calendar access is restricted on this device.")
            case .saveFailed(let error):
                return String(localized: "Could not save event: \(error.localizedDescription)")
            case .unknown:
                return String(localized: "An unknown error occurred.")
            }
        }
    }

    func addEvent(
        title: String,
        startDate: Date,
        endDate: Date?,
        location: String?,
        notes: String?
    ) async throws {
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = title
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate ?? startDate.addingTimeInterval(3600) // Default +1 hour
        ekEvent.location = location
        ekEvent.notes = notes
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
        } catch {
            throw CalendarError.saveFailed(error)
        }
    }

    private func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
}
