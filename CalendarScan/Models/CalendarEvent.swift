import Foundation

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String?
    var ekEventIdentifier: String?

    init(title: String, startDate: Date, endDate: Date, location: String? = nil, notes: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.ekEventIdentifier = nil
    }

    /// Whether two events represent the same real-world event (by title + day).
    func matches(_ other: CalendarEvent) -> Bool {
        let selfTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
        let otherTitle = other.title.lowercased().trimmingCharacters(in: .whitespaces)
        let sameTitle = selfTitle == otherTitle
        let sameDay = Calendar.current.isDate(startDate, inSameDayAs: other.startDate)
        return sameTitle && sameDay
    }

    /// Whether the content of two matched events is identical.
    func isContentEqual(to other: CalendarEvent) -> Bool {
        abs(startDate.timeIntervalSince(other.startDate)) < 60 &&
        abs(endDate.timeIntervalSince(other.endDate)) < 60 &&
        location == other.location &&
        notes == other.notes
    }
}
