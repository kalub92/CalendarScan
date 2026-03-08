import SwiftUI
import Observation

@Observable
@MainActor
final class MainViewModel {
    var calendarEvents: [CalendarEvent] = []
    var pendingDiff: EventDiff?
    var isAnalyzing = false
    var errorMessage: String?
    var hasCalendarAccess = false

    private let calendarService = CalendarService()

    // MARK: - Setup

    func setup() async {
        do {
            try await calendarService.setup()
            hasCalendarAccess = true
            refreshEvents()
        } catch CalendarError.accessDenied {
            // Permission was denied — keep hasCalendarAccess false to show the prompt
            errorMessage = CalendarError.accessDenied.errorDescription
        } catch {
            // Permission was granted but calendar creation failed (e.g. account restrictions).
            // Allow the main UI to load and surface the error as a banner instead.
            hasCalendarAccess = true
            errorMessage = error.localizedDescription
            refreshEvents()
        }
    }

    func refreshEvents() {
        calendarEvents = calendarService.fetchEvents()
    }

    // MARK: - Scanning

    func scan(image: UIImage) async {
        let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        guard !apiKey.isEmpty else {
            errorMessage = "Add your OpenAI API key in Settings before scanning."
            return
        }

        isAnalyzing = true
        errorMessage = nil

        do {
            let service = OpenAIService(apiKey: apiKey)
            let scannedEvents = try await service.extractEvents(from: image)
            let diff = computeDiff(existing: calendarEvents, scanned: scannedEvents)

            if diff.isEmpty {
                errorMessage = "Scan complete — no changes detected."
            } else {
                pendingDiff = diff
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    // MARK: - Applying Changes

    func applyDiff() async {
        guard let diff = pendingDiff else { return }

        do {
            for event in diff.removed {
                if let id = event.ekEventIdentifier {
                    try calendarService.removeEvent(identifier: id)
                }
            }
            for event in diff.added {
                try calendarService.addEvent(event)
            }
            for (old, new) in diff.updated {
                if let id = old.ekEventIdentifier {
                    try calendarService.updateEvent(identifier: id, with: new)
                }
            }
            pendingDiff = nil
            refreshEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissDiff() {
        pendingDiff = nil
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Diff Computation

    private func computeDiff(existing: [CalendarEvent], scanned: [CalendarEvent]) -> EventDiff {
        var added: [CalendarEvent] = []
        var removed: [CalendarEvent] = []
        var updated: [(old: CalendarEvent, new: CalendarEvent)] = []

        for scannedEvent in scanned {
            if let match = existing.first(where: { $0.matches(scannedEvent) }) {
                if !match.isContentEqual(to: scannedEvent) {
                    updated.append((old: match, new: scannedEvent))
                }
            } else {
                added.append(scannedEvent)
            }
        }

        for existingEvent in existing {
            if !scanned.contains(where: { existingEvent.matches($0) }) {
                removed.append(existingEvent)
            }
        }

        return EventDiff(added: added, removed: removed, updated: updated)
    }
}
