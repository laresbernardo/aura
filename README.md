# Aura — macOS Music Analytics Dashboard

Aura is a native **macOS SwiftUI** app that turns your macOS Music library into a beautiful analytics dashboard. It reads your tracks, play counts, skip counts, star ratings, and timestamps directly from the Music Library XML file — no permissions or automation prompts required.

Think of it as **Spotify Wrapped, but for your local library, live and always up to date.**

---

## 🎵 What Aura Shows You

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
Tracks you rated 4–5 stars but haven't played in over two years.

---

## 🚀 Architecture

- **XML Library Reader**: Reads `Music Library.xml` (the standard Apple plist export) directly from disk. No JXA, no automation permissions — just file I/O. Parses thousands of tracks in under a second.
- **Pure SwiftUI + Swift Charts**: No third-party dependencies.
- **Glassmorphism UI**: `NSVisualEffectView` via `NSViewRepresentable` for frosted-glass panels.
- **Demo Mode**: Ships with 120+ pre-seeded tracks so the dashboard works immediately out of the box.
- **Privacy-first**: Aura reads only the XML export file Music writes to disk. It never contacts Apple servers or modifies your library.

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
