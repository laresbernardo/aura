# Aura — macOS Music & Photos Analytics Dashboard

Aura is a native **macOS SwiftUI** app that turns your macOS Music and Apple Photos libraries into a beautiful, premium analytics dashboard. It visually distinguishes between the two modes with dynamic thematic styling (violet for Music, emerald for Photos) and enforces robust date-range isolation.

Think of it as **Spotify Wrapped and visual library insights, live and always up to date.**

---

## 🎵 Music Mode Dashboards

### 🔭 Overview Dashboard
- **Total tracks** and estimated **cumulative listening time**
- **Top artist** by all-time play count and **primary genre** by track volume
- **Genre composition** bar chart across your library

### 📊 Listening Habits
- **Top 20 most-played tracks** — your true hall-of-fame songs
- **Skip rate analysis** — which tracks you never finish
- **Rating vs. plays scatter** — do your 5-star tracks get the most plays?
- **Era distribution** — what decade dominates your listening

### ⏳ Time Machine
- **Month-by-month chart** of when you added music, revealing discovery periods
- Genre preference shifts over the years

### 💎 Forgotten Gems
- Tracks you rated 4–5 stars but haven't played in over two years.

---

## 📸 Photos Mode Dashboards

### 🔭 Overview & Capture Timeline
- **Total captures**, video count, still photo counts, and favorite ratios
- **Media composition** (Still Photos, Videos, Live Photos) donut distribution
- **Capture history timeline** showing library growth month-by-month

### 📊 Capture Behavior & Gear
- **24-hour Capture Clock** showing hourly capture density distribution
- **Camera Gear** distribution (e.g. Sony A7R V, Fujifilm X-T5, DJI Mavic, iPhone)
- **Crop aspect ratio** composition (Panoramic, Landscape, Portrait, Square)

### 🗺️ Visited Places & Altitudes
- **Geographic distribution** tracking total cities and countries visited
- **Destination stats** table sorting your most photographed locations
- **Altitude profile** chart categorizing elevations from sea level up to mountain peaks

### 🔮 Photography Persona
- **Glowing Aura profile cards** (e.g., "The Visual Explorer") based on travel index, gear utilization, variety index, and favorite curation.

---

## 🚀 Architecture

- **XML Library Reader (Music)**: Reads `Music Library.xml` (the standard Apple plist export) directly from disk. No automation permissions — just clean file I/O. Parses thousands of tracks in under a second.
- **Native PhotoKit (Photos)**: Integrates directly with Apple's `PHPhotoLibrary` to query `PHAsset` objects asynchronously in background threads. Processes 3,000 photos in under 50ms with a real-time UI loading progress tracker.
- **Geocoding & Elevation Engine**: Resolves captured latitudes/longitudes using `CLGeocoder`, rounds to 2 decimal places to bypass duplicate queries (~1km precision), and caches results locally in `UserDefaults` to respect system rate limits.
- **Pure SwiftUI + Swift Charts**: No third-party dependencies.
- **Glassmorphic UI**: Integrates `NSVisualEffectView` via `NSViewRepresentable` to create frosted glass responsive layouts.
- **Offline Demo Mode**: Pre-loaded with 120+ music tracks and 1,320 photos so dashboards are interactive immediately.
- **Privacy-first**: Parses files locally and utilizes direct read-only sandbox bridges. Data never leaves your machine.

---

## 🛠️ Installation

### 1-Step Script (Recommended)

```bash
cd Aura
./install.sh
```

This compiles all Swift sources, signs the app (ad-hoc), and installs it directly to `/Applications/Aura.app`. Aura launches automatically when done.

---

## 🔐 Connecting Your Real Library (One-Time Setup)

Aura reads the Music Library XML file that Music.app writes to disk. You need to enable this export once:

1. Open **Music.app**.
2. Go to **Music → Settings → Files** tab.
3. Tick **"Share Music Library XML with other applications"**.
4. In Aura, toggle **Demo Library → OFF** in the sidebar. Your library loads instantly.

> No permission prompts. No automation entitlements. Aura just reads the file.

---

## ⚠️ Gatekeeper Warning

If macOS blocks the app as "unverified developer" (only relevant if you share the DMG externally):

1. Open **System Settings → Privacy & Security → Security**.
2. Find the blocked Aura entry and click **Open Anyway**.

The `./install.sh` script installs directly to `/Applications` using `xattr -cr` to clear quarantine, so this warning should not appear for local builds.

---

## ⚡ Credits

Aura is developed by **[BERVOS](https://bervos.org)**.

<p align="center">
  <a href="https://bervos.org">
    <img src="AuraApp/BervosLogo.png" alt="BERVOS Logo" width="120" />
  </a>
</p>

