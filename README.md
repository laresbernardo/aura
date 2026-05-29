# Aura Music Analytics Dashboard: macOS Setup Guide

Aura is a native, premium macOS SwiftUI application designed to analyze your listening habits directly from your native macOS Music app (formerly iTunes). Using a highly optimized **JXA (JavaScript for Automation)** bulk bridge, Aura aggregates track counts, plays, skips, eras, and dates in a split second, displaying them in a premium, modern, dark-mode dashboard using native **Swift Charts**.

---

## 🚀 Project Highlights & Architecture

To achieve a premium modern SaaS aesthetic, Aura leverages:
- **Pure SwiftUI & Glassmorphism**: Native blur and transparency overlay structures (`NSVisualEffectView` integration via `NSViewRepresentable`) paired with subtle accent gradients.
- **High-Performance JXA Bridge**: Rather than querying thousands of songs track-by-track (which locks the main thread), Aura bulk-queries system arrays in JavaScript (e.g., `tracks.playedCount()`), improving query speeds **by 100x** (takes ~1 second for 5,000+ songs!).
- **Dual Library Engine**: Preconfigured with a beautiful, offline **Demo Mode** containing 120+ simulated tracks across synthwave, shoegaze, jazz, rock, and lofi genres, mapping complex playlists, eras, and forgotten classics out-of-the-box.
- **Privacy Entitlements Integration**: Comprehensive Info.plist authorization prompts and Sandbox entitlement files to handle macOS Automation security natively.

---

## 🛠️ Installation & Build Options

You can set up and run Aura on your Mac using two different workflows. **Option 1 (DMG Compiler Script)** is highly recommended as it packages everything into a standard double-clickable installer in under 2 seconds.

### Option 1: The 1-Step DMG Compiler Script (Recommended)
This method compiles all the Swift files natively on your Mac, signs the binary with local entitlements, and packs it into a premium drag-and-drop `Aura.dmg` disk installer automatically.

1. Open **Terminal** on your Mac.
2. Navigate to your cloned repository folder and run the compile script:
   ```bash
   cd Aura
   ./build_dmg.sh
   ```
3. Once completed, double-click the newly generated **`Aura.dmg`** file in your project root.
4. Drag the **Aura** icon into your **Applications** shortcut!

---

### Option 2: Manual Xcode Integration (For App Developers)
If you want to customize or modify the SwiftUI UI components directly within Apple's visual editor:

1. **Create Project**: Launch Xcode and select **File** > **New** > **Project...** > **macOS** tab > **App**.
   - Set **Product Name** to `Aura`, **Interface** to `SwiftUI`, and **Language** to `Swift`.
2. **Copy Source Files**: Drag the files inside `MusicDashboard/` from your local workspace into your Xcode sidebar:
   - `Models.swift`
   - `MusicLibraryManager.swift`
   - `GlassCard.swift`
   - `Views/` (`MainView.swift`, `OverviewDashboardView.swift`, `ListeningHabitsView.swift`, `TimeMachineView.swift`)
   - `MusicDashboardApp.swift` (replaces default App file)
3. **Enable Sandboxing & Automation Entitlements**:
   - Select `Aura.entitlements` in your Xcode sidebar and set `com.apple.security.automation.apple-events` to `Boolean` `YES`.
   *(Or copy entitlements XML code from `MusicDashboard/MusicDashboard.entitlements`)*
4. **Add Info.plist Authorization Prompt**:
   - Select your project file, go to the **Info** tab, hover to click `+` and add `Privacy - AppleEvents Sending Usage Description` (`NSAppleEventsUsageDescription`).
   - Set its string value to: `Aura requires permissions to automate the macOS Music app to fetch song statistics and build your personal dashboard.`
5. **Build & Run**: Press **`cmd + R`** or click **Play** in Xcode.

---

## 🔐 First-Run Privacy Permissions

Because Aura is a secure app querying another macOS utility, macOS will request verification on first run:

1. If you toggle **Demo Library** to OFF in the sidebar, Aura connects to your local macOS Music app.
2. macOS will show a system prompt:
   > *"Aura" wants access to control "Music.app".*
3. Click **OK** to securely sync.

### ⚠️ Troubleshooting Unsigned Apps (For Distributed DMGs):
If you download the `.dmg` from the web or share it with others, macOS Gatekeeper may show a warning stating the developer is unverified. To open it:
1. Open the DMG, drag **Aura** into your **Applications** folder.
2. Go to **System Settings** > **Privacy & Security** > scroll down to the **Security** section.
3. Find *"Aura.app was blocked from use because it is not from an identified developer."* and click **Open Anyway**.

If you accidentally click "Don't Allow" on the automation pop-up:
- Go to **System Settings** > **Privacy & Security** > **Automation**.
- Find **Aura** in the list and toggle **Music** to ON (green).
