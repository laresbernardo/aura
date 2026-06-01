import SwiftUI

@main
struct MusicDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark) // Enforces default premium dark mode
        }
        .windowStyle(.hiddenTitleBar) // Sleek, unified window frame
        .windowToolbarStyle(.unifiedCompact)
    }
}
