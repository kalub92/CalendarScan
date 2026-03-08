import SwiftUI

struct EventsReviewView: View {
    let diff: EventDiff
    let onApply: () async -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if !diff.added.isEmpty {
                    Section("Adding \(diff.added.count) event\(diff.added.count == 1 ? "" : "s")") {
                        ForEach(diff.added) { event in
                            EventDiffRow(event: event, style: .added)
                        }
                    }
                }

                if !diff.removed.isEmpty {
                    Section("Removing \(diff.removed.count) event\(diff.removed.count == 1 ? "" : "s")") {
                        ForEach(diff.removed) { event in
                            EventDiffRow(event: event, style: .removed)
                        }
                    }
                }

                if !diff.updated.isEmpty {
                    Section("Updating \(diff.updated.count) event\(diff.updated.count == 1 ? "" : "s")") {
                        ForEach(diff.updated, id: \.old.id) { pair in
                            EventUpdateRow(old: pair.old, new: pair.new)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Task { await onApply() }
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Row Views

private enum DiffStyle {
    case added, removed
    var color: Color { self == .added ? .green : .red }
    var icon: String { self == .added ? "plus.circle.fill" : "minus.circle.fill" }
}

private struct EventDiffRow: View {
    let event: CalendarEvent
    let style: DiffStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: style.icon)
                .foregroundStyle(style.color)
                .font(.title3)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
                Text(event.startDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EventUpdateRow: View {
    let old: CalendarEvent
    let new: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(new.title)
                    .font(.headline)

                if !Calendar.current.isDate(old.startDate, equalTo: new.startDate, toGranularity: .minute) {
                    HStack(spacing: 4) {
                        Text("\(old.startDate, style: .time)")
                            .strikethrough()
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(new.startDate, style: .time)")
                    }
                    .font(.subheadline)
                }

                Text(new.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
