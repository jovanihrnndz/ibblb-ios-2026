import Foundation

extension DateFormatter {
    static let sermonDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        // Output format like "Dec 20, 2025"
        return formatter
    }()
}

extension Date {
    var formattedSermonDate: String {
        DateFormatter.sermonDate.string(from: self)
    }
    
    /// Returns true if the date's time component is at the start of the day (midnight)
    /// This helps determine if an event has a specific time set or just a date
    var isAtStartOfDay: Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: self)
        return components.hour == 0 && components.minute == 0 && components.second == 0
    }
    
    /// Formats the date conditionally: shows only date if time is at start of day,
    /// otherwise shows both date and time
    func formattedEventDate() -> String {
        if isAtStartOfDay {
            return formatted(date: .long, time: .omitted)
        } else {
            return formatted(date: .long, time: .shortened)
        }
    }
}
