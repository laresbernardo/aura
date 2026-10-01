import SwiftUI

@main
struct MusicDashboardApp: App {
    @StateObject private var updates = UpdateChecker()

    var body: some Scene {
        WindowGroup {
            MainView()
                .safeAreaInset(edge: .top, spacing: 0) { UpdateNotice(updates: updates) }
                .task { await updates.launch() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await updates.reactivate() }
                }
                .alert("Check for Updates", isPresented: Binding(
                    get: { updates.message != nil },
                    set: { if !$0 { updates.message = nil } }
                )) { Button("OK") { updates.message = nil } } message: { Text(updates.message ?? "") }
                .preferredColorScheme(.dark) // Enforces default premium dark mode
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button(updates.checking ? "Checking for Updates..." : "Check for Updates") {
                    Task { await updates.check(manual: true) }
                }.disabled(updates.checking)
            }
        }
        .windowStyle(.hiddenTitleBar) // Sleek, unified window frame
        .windowToolbarStyle(.unifiedCompact)
    }
}
