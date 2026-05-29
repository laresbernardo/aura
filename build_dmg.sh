#!/bin/bash

# Aura macOS Compiler & DMG Packaging Script
# This script compiles the Aura Swift source code into a native macOS .app bundle,
# signs it with local entitlements, and wraps it in a drag-and-drop DMG installer.

set -e # Exit immediately if any command fails

# Define visual terminal output styling
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}        AURA MAC MUSIC DASHBOARD BUILD SYSTEM     ${NC}"
echo -e "${BLUE}==================================================${NC}"

# 1. Verify Operating System environment is macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script requires macOS tools (swiftc, codesign, hdiutil) to run.${NC}"
    echo -e "Please run this script on your local Mac."
    exit 1
fi

# 2. Check for Swift Compiler availability
if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}Error: Swift compiler (swiftc) not found.${NC}"
    echo -e "Please ensure Xcode Command Line Tools or Xcode are installed."
    exit 1
fi

# 3. Clean up previous build relics
echo -e "${YELLOW}Cleaning up previous build artifacts...${NC}"
rm -rf Aura.app
rm -rf Aura.dmg
rm -rf dmg_temp

# 4. Construct .app bundle directories
echo -e "${YELLOW}Constructing macOS Application bundle structures...${NC}"
mkdir -p Aura.app/Contents/MacOS
mkdir -p Aura.app/Contents/Resources

# 5. Compile Swift Source files natively
echo -e "${YELLOW}Compiling Swift sources natively (optimizing bundle)...${NC}"
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

swiftc -O -sdk "$SDK_PATH" \
    -o Aura.app/Contents/MacOS/Aura \
    MusicDashboard/Models.swift \
    MusicDashboard/MusicLibraryManager.swift \
    MusicDashboard/GlassCard.swift \
    MusicDashboard/Views/MainView.swift \
    MusicDashboard/Views/OverviewDashboardView.swift \
    MusicDashboard/Views/ListeningHabitsView.swift \
    MusicDashboard/Views/TimeMachineView.swift \
    MusicDashboard/MusicDashboardApp.swift

echo -e "${GREEN}✓ Compilation completed successfully.${NC}"

# 6. Inject Plist Configurations
echo -e "${YELLOW}Injecting metadata configurations into App bundle...${NC}"
if [ -f "MusicDashboard/Info.plist" ]; then
    cp MusicDashboard/Info.plist Aura.app/Contents/Info.plist
else
    echo -e "${RED}Error: MusicDashboard/Info.plist not found.${NC}"
    exit 1
fi

# 7. Sign application with Automation Entitlements locally
echo -e "${YELLOW}Performing local ad-hoc code signing with security entitlements...${NC}"
if [ -f "MusicDashboard/MusicDashboard.entitlements" ]; then
    codesign --force --options runtime --entitlements MusicDashboard/MusicDashboard.entitlements --sign - Aura.app
    echo -e "${GREEN}✓ Code signing and sandbox permissions verified.${NC}"
else
    echo -e "${YELLOW}Warning: MusicDashboard.entitlements not found. Compiling unsigned bundle...${NC}"
    codesign --force --sign - Aura.app
fi

# 8. Package App into a Premium Drag-and-Drop DMG installer
echo -e "${YELLOW}Packaging application into a UDZO-compressed DMG installer...${NC}"
mkdir -p dmg_temp
cp -R Aura.app dmg_temp/
ln -s /Applications dmg_temp/Applications

hdiutil create -volname "Aura Installer" -srcfolder dmg_temp -ov -format UDZO Aura.dmg

# 9. Success cleanup
rm -rf dmg_temp
echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}🚀 BUILD SUCCESSFUL! Aura is ready for installation!${NC}"
echo -e "${GREEN}Location: $(pwd)/Aura.dmg${NC}"
echo -e "${BLUE}==================================================${NC}"
echo -e "To install, simply double-click ${YELLOW}Aura.dmg${NC} and drag ${YELLOW}Aura.app${NC} into your Applications folder."
