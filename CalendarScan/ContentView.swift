import SwiftUI

struct ContentView: View {
    @Environment(MainViewModel.self) private var viewModel

    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.hasCalendarAccess {
                    calendarAccessPrompt
                } else if viewModel.calendarEvents.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .navigationTitle("CalendarScan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.isAnalyzing {
                        ProgressView()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.hasCalendarAccess {
                    scanButton
                        .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Reserve space for the floating scan button
                if viewModel.hasCalendarAccess {
                    Color.clear.frame(height: 80)
                }
            }
        }
        // Camera / photo library sheets
        .sheet(isPresented: $showCamera) {
            CameraPickerView(sourceType: .camera) { image in
                Task { await viewModel.scan(image: image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            CameraPickerView(sourceType: .photoLibrary) { image in
                Task { await viewModel.scan(image: image) }
            }
            .ignoresSafeArea()
        }
        // Diff review sheet
        .sheet(item: Bindable(viewModel).pendingDiff) { diff in
            EventsReviewView(
                diff: diff,
                onApply: { await viewModel.applyDiff() },
                onDismiss: { viewModel.dismissDiff() }
            )
        }
        // Settings sheet
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        // Error banner
        .overlay(alignment: .top) {
            if let message = viewModel.errorMessage {
                ErrorBanner(message: message) {
                    viewModel.clearError()
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring, value: viewModel.errorMessage != nil)
            }
        }
    }

    // MARK: - Subviews

    private var eventList: some View {
        List {
            ForEach(groupedEvents, id: \.0) { date, events in
                Section(header: Text(date, style: .date).font(.headline)) {
                    ForEach(events) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { viewModel.refreshEvents() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Events Yet")
                .font(.title2.bold())
            Text("Tap Scan to photograph your paper calendar\nand automatically import events.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var calendarAccessPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Calendar Access Needed")
                .font(.title2.bold())
            Text("CalendarScan needs access to your calendar to create and sync events.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var scanButton: some View {
        Menu {
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            Button {
                showPhotoLibrary = true
            } label: {
                Label("Choose from Library", systemImage: "photo")
            }
        } label: {
            Label(
                viewModel.isAnalyzing ? "Analyzing..." : "Scan Calendar",
                systemImage: viewModel.isAnalyzing ? "ellipsis.circle" : "camera.viewfinder"
            )
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(viewModel.isAnalyzing ? Color.secondary : Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(radius: 6, y: 3)
        }
        .disabled(viewModel.isAnalyzing)
    }

    // MARK: - Helpers

    private var groupedEvents: [(Date, [CalendarEvent])] {
        let grouped = Dictionary(grouping: viewModel.calendarEvents) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }
        return grouped.sorted { $0.key < $1.key }
    }
}

// MARK: - EventRow

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.body.weight(.medium))
            HStack {
                Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let location = event.location, !location.isEmpty {
                    Spacer()
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ErrorBanner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.footnote)
                .lineLimit(3)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.bold())
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
    }
}
