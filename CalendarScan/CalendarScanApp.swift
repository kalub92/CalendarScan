import SwiftUI

@main
struct CalendarScanApp: App {
    @State private var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .task {
                    await viewModel.setup()
                }
        }
    }
}
