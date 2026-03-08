import Foundation

struct EventDiff: Identifiable {
    let id = UUID()
    let added: [CalendarEvent]
    let removed: [CalendarEvent]
    let updated: [(old: CalendarEvent, new: CalendarEvent)]

    var isEmpty: Bool {
        added.isEmpty && removed.isEmpty && updated.isEmpty
    }

    var totalChanges: Int {
        added.count + removed.count + updated.count
    }
}
