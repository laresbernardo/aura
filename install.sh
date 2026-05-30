#!/bin/bash

# Aura macOS Build & Install Script
# Compiles Swift sources, installs Aura directly to /Applications,
# and clears all Gatekeeper quarantine flags — no manual steps required.
# Also produces Aura.dmg for sharing/distribution.

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}        AURA MAC MUSIC DASHBOARD BUILD SYSTEM     ${NC}"
echo -e "${BLUE}==================================================${NC}"

# 1. Verify macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script requires macOS.${NC}"
    exit 1
fi

# 2. Check Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}Error: Swift compiler not found.${NC}"
    echo -e "Run: xcode-select --install"
    exit 1
fi

# Build entirely in /tmp (local disk) to avoid macOS quarantine-stamping
# anything that lives on a cloud-synced volume (Google Drive, iCloud, etc.)
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/AuraBuild"
APP_BUNDLE="$BUILD_DIR/Aura.app"
DMG_STAGING="$BUILD_DIR/dmg_staging"
DMG_LOCAL="$BUILD_DIR/Aura.dmg"
INSTALL_DEST="/Applications/Aura.app"
FINAL_DMG="$SOURCE_DIR/Aura.dmg"

# 3. Clean up
echo -e "${YELLOW}Cleaning previous build artifacts...${NC}"
rm -rf "$BUILD_DIR" "$FINAL_DMG"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$DMG_STAGING"

# 4. Compile directly into /tmp
echo -e "${YELLOW}Compiling Swift sources → /tmp ...${NC}"
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

swiftc -O -sdk "$SDK_PATH" \
    -o "$APP_BUNDLE/Contents/MacOS/Aura" \
    "$SOURCE_DIR/MusicDashboard/Models.swift" \
    "$SOURCE_DIR/MusicDashboard/MusicLibraryManager.swift" \
    "$SOURCE_DIR/MusicDashboard/GlassCard.swift" \
    "$SOURCE_DIR/MusicDashboard/Views/MainView.swift" \
    "$SOURCE_DIR/MusicDashboard/Views/OverviewDashboardView.swift" \
    "$SOURCE_DIR/MusicDashboard/Views/ListeningHabitsView.swift" \
    "$SOURCE_DIR/MusicDashboard/Views/TimeMachineView.swift" \
    "$SOURCE_DIR/MusicDashboard/Views/ArtistHallView.swift" \
    "$SOURCE_DIR/MusicDashboard/Views/AuraProfileView.swift" \
    "$SOURCE_DIR/MusicDashboard/MusicDashboardApp.swift"

echo -e "${GREEN}✓ Compilation successful.${NC}"

# 5. Inject Info.plist & Auto-increment Version
PLIST_FILE="$SOURCE_DIR/MusicDashboard/Info.plist"
if [ -f "$PLIST_FILE" ]; then
    CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST_FILE")
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    NEXT_PATCH=$((patch + 1))
    NEW_VERSION="$major.$minor.$NEXT_PATCH"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$PLIST_FILE"
    
    CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST_FILE")
    NEW_BUILD=$((CURRENT_BUILD + 1))
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST_FILE"
    
    echo -e "${GREEN}✓ Version bumped to $NEW_VERSION (Build $NEW_BUILD)${NC}"
fi

cp "$PLIST_FILE" "$APP_BUNDLE/Contents/Info.plist"

# 5b. Generate .icns app icon from AppIcon.png (if provided)
ICON_SOURCE="$SOURCE_DIR/MusicDashboard/AppIcon.png"
if [ -f "$ICON_SOURCE" ]; then
    echo -e "${YELLOW}Generating app icon from AppIcon.png...${NC}"
    ICONSET="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET"
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png"     > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png"  > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png"     > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png"  > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png"   > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png"> /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png"   > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png"> /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png"   > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png"> /dev/null
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    echo -e "${GREEN}✓ App icon generated and bundled.${NC}"
fi

# 6. Deep ad-hoc code sign (--deep covers nested binaries/frameworks)
echo -e "${YELLOW}Code signing (deep, ad-hoc)...${NC}"
ENTITLEMENTS="$SOURCE_DIR/MusicDashboard/MusicDashboard.entitlements"
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --deep --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign - "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

# 7. Strip all extended attributes while the bundle is on local disk
xattr -rc "$APP_BUNDLE"
echo -e "${GREEN}✓ Signed and quarantine-cleared.${NC}"

# ─── DIRECT INSTALL TO /Applications ────────────────────────────────────────
# This is the reliable, no-UX-friction path. We copy straight from /tmp
# (never touched a cloud volume) into /Applications, then strip xattr again
# on the destination and re-sign in place — belt AND suspenders.

echo -e "${YELLOW}Installing Aura → /Applications ...${NC}"
rm -rf "$INSTALL_DEST"
ditto "$APP_BUNDLE" "$INSTALL_DEST"

# Strip quarantine on the installed copy
xattr -rc "$INSTALL_DEST"

# Re-sign the installed copy in place
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --deep --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign - "$INSTALL_DEST"
else
    codesign --force --deep --sign - "$INSTALL_DEST"
fi

echo -e "${GREEN}✓ Aura installed to /Applications/Aura.app${NC}"

# ─── ALSO BUILD DMG FOR DISTRIBUTION ────────────────────────────────────────
echo -e "${YELLOW}Packaging Aura.dmg for distribution...${NC}"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "Aura Installer" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_LOCAL" > /dev/null

# Strip quarantine from the DMG itself before copying back to Drive
xattr -rc "$DMG_LOCAL"
cp "$DMG_LOCAL" "$FINAL_DMG"

# Clean up /tmp
rm -rf "$BUILD_DIR"

# ─── LAUNCH ──────────────────────────────────────────────────────────────────
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}🚀 BUILD & INSTALL SUCCESSFUL!${NC}"
echo -e "${GREEN}Aura is installed at: /Applications/Aura.app${NC}"
echo -e "${GREEN}DMG for sharing:      $FINAL_DMG${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "Launching Aura..."
open "$INSTALL_DEST"
