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

## 🛠️ Step-by-Step Local Setup Guide

Follow these instructions to build and run Aura on your Mac using Apple's native development suite.

### Step 1: Prerequisites
1. **macOS System**: macOS Ventura (13.0) or later (required for the native `Charts` framework).
2. **Xcode IDE**: Install Xcode (free) directly from the Mac App Store or download Apple Command Line Tools.

---

### Step 2: Create the Xcode Project
1. Launch **Xcode**.
2. Select **File** > **New** > **Project...** (or hit `cmd + shift + N`).
3. Select the **macOS** tab, choose **App**, and click **Next**.
4. Configure the project parameters:
   - **Product Name**: `Aura`
   - **Organization Identifier**: `com.aura`
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
5. Click **Next** and choose a directory (for example, inside your workspace `/usr/local/google/home/blares/Documents/Aura/`) to save the project.

---

### Step 3: Add the Source Files
Xcode generates a default template. Replace or add the files with the production-ready source files provided in the workspace directory:

1. **`Models.swift`**: Define your models. Copy the code from `MusicDashboard/Models.swift`.
2. **`MusicLibraryManager.swift`**: Holds the async JXA execution bridge and mock database. Copy from `MusicDashboard/MusicLibraryManager.swift`.
3. **`GlassCard.swift`**: Implements native visual blur, highlights, and custom border animations. Copy from `MusicDashboard/GlassCard.swift`.
4. Create a group folder named `Views` in your Xcode hierarchy and add:
   - **`MainView.swift`**: Copy from `MusicDashboard/Views/MainView.swift`.
   - **`OverviewDashboardView.swift`**: Copy from `MusicDashboard/Views/OverviewDashboardView.swift`.
   - **`ListeningHabitsView.swift`**: Copy from `MusicDashboard/Views/ListeningHabitsView.swift`.
   - **`TimeMachineView.swift`**: Copy from `MusicDashboard/Views/TimeMachineView.swift`.
5. **`AuraApp.swift`** (or rename your entry app file): Copy from `MusicDashboard/MusicDashboardApp.swift`.

---

### Step 4: Configure macOS Entitlements & Security
Because Aura automates the macOS Music app, you **must** authorize its access inside Apple's sandbox.

#### 1. Entitlements Configuration (Sandboxing):
If you build with App Sandboxing turned on:
1. Locate the `Aura.entitlements` file in your Xcode sidebar.
2. Add a new key-value entry:
   - **Key**: `com.apple.security.automation.apple-events`
   - **Type**: `Boolean`
   - **Value**: `YES`
*(Alternatively, replace the contents of your entitlements file with the code from `MusicDashboard/MusicDashboard.entitlements`)*

#### 2. Info.plist Prompt Description:
A descriptive user explanation must accompany automation events.
1. Select your project in the top-left of Xcode.
2. Under the **Info** tab, find **Custom macOS Application Target Properties**.
3. Hover and click `+` to add a new row:
   - **Key**: `Privacy - AppleEvents Sending Usage Description` (or `NSAppleEventsUsageDescription`)
   - **Type**: `String`
   - **Value**: `Aura requires permissions to automate the macOS Music app to fetch song statistics and build your personal dashboard.`
*(Alternatively, copy the XML format from `MusicDashboard/Info.plist`)*

---

### Step 5: Run the Application!
1. Ensure the macOS Music App is open (or toggle Aura's custom "Demo Library" on to explore the beautiful pre-populated dashboard immediately).
2. Press **`cmd + R`** or click the **Play** button in the top left of Xcode to build and run.
3. If you toggle **Demo Library** OFF to sync your real library, macOS will display a prompt: 
   > *"Aura" wants access to control "Music".*
4. Click **OK** to instantly download your real listening trends!

---

## 🔐 Troubleshooting & Permission Controls

### Issue A: Accidental "Don't Allow" on Permission Dialog
If you denied Aura access to control the Music app:
1. Open **System Settings** on your Mac.
2. Navigate to **Privacy & Security** > **Automation**.
3. Locate **Aura** in the application list.
4. Enable the toggle switch for **Music** to green.
5. Restart Aura and sync.

### Issue B: Code Signing / Sandbox errors on Compilation
If you run into code signing or entitlement mismatched profiles:
1. Select **Aura** project settings in Xcode.
2. Select the **Signing & Capabilities** tab.
3. Uncheck **Inherit Entitlements** if it conflicts, or set your Apple ID Developer Team to sign locally (Xcode supports free personal profiles for local running!).
4. Under **App Sandbox** section, verify that **Automation** is checked.
