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
}
