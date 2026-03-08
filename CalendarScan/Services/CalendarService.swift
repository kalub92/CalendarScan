import EventKit
import UIKit
import Foundation

@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private let calendarName = "CalendarScan"
    private var appCalendar: EKCalendar?

    // MARK: - Setup

    func setup() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw CalendarError.accessDenied }
        appCalendar = try getOrCreateCalendar()
    }

    // MARK: - Calendar Management

    private func getOrCreateCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarName }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarName

        // Prefer iCloud so events sync to iPhone; fall back to local storage
        let source = store.sources.first(where: { $0.sourceType == .calDAV })
                  ?? store.sources.first(where: { $0.sourceType == .exchange })
                  ?? store.sources.first(where: { $0.sourceType == .local })

        guard let source else { throw CalendarError.noCalendarSource }
        calendar.source = source

        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    // MARK: - Event Fetching

    func fetchEvents() -> [CalendarEvent] {
        guard let calendar = appCalendar else { return [] }

        let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let end   = Calendar.current.date(byAdding: .month, value: 13, to: Date())!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])

        return store.events(matching: predicate).map { CalendarEvent(ekEvent: $0) }
    }

    // MARK: - Event CRUD

    @discardableResult
    func addEvent(_ event: CalendarEvent) throws -> String {
        guard let calendar = appCalendar else { throw CalendarError.notSetup }

        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title    = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate   = event.endDate
        ekEvent.location  = event.location
        ekEvent.notes     = event.notes
        ekEvent.calendar  = calendar

        try store.save(ekEvent, span: .thisEvent, commit: true)
        return ekEvent.eventIdentifier
    }

    func removeEvent(identifier: String) throws {
        guard let ekEvent = store.event(withIdentifier: identifier) else { return }
        try store.remove(ekEvent, span: .thisEvent, commit: true)
    }

    func updateEvent(identifier: String, with event: CalendarEvent) throws {
        guard let ekEvent = store.event(withIdentifier: identifier) else {
            throw CalendarError.eventNotFound
        }
        ekEvent.title     = event.title
        ekEvent.startDate = event.startDate
        ekEvent.endDate   = event.endDate
        ekEvent.location  = event.location
        ekEvent.notes     = event.notes
        try store.save(ekEvent, span: .thisEvent, commit: true)
    }
}

// MARK: - CalendarEvent init from EKEvent

extension CalendarEvent {
    init(ekEvent: EKEvent) {
        self.id                = UUID().uuidString
        self.title             = ekEvent.title ?? "Untitled"
        self.startDate         = ekEvent.startDate
        self.endDate           = ekEvent.endDate
        self.location          = ekEvent.location
        self.notes             = ekEvent.notes
        self.ekEventIdentifier = ekEvent.eventIdentifier
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case accessDenied
    case noCalendarSource
    case notSetup
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .accessDenied:       return "Calendar access was denied. Please enable it in Settings."
        case .noCalendarSource:   return "No calendar account found. Please add an account in Settings."
        case .notSetup:           return "Calendar service is not ready yet."
        case .eventNotFound:      return "The event could not be found in your calendar."
        }
    }
}
