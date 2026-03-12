#!/bin/bash
set -e

PRODUCT="ProjectPulse"
DERIVED=".build/xcode"
APP_DIR="$DERIVED/Build/Products/Release/$PRODUCT.app"
INSTALL_DIR="$HOME/Applications"

# Quit if running
osascript -e 'quit app "ProjectPulse"' 2>/dev/null || true
sleep 1

# Build with xcodebuild (includes widget extension)
xcodebuild -project ProjectPulse.xcodeproj \
    -scheme ProjectPulse \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -allowProvisioningUpdates \
    build 2>&1 | grep -E "(error:|BUILD|Linking)" || true

# Install
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$PRODUCT.app"
cp -r "$APP_DIR" "$INSTALL_DIR/"

# Register widget plugin
pluginkit -a "$INSTALL_DIR/$PRODUCT.app/Contents/PlugIns/ProjectPulseWidgetExtension.appex" 2>/dev/null || true

# Launch
open "$INSTALL_DIR/$PRODUCT.app"

echo ""
echo "Installed and launched $INSTALL_DIR/$PRODUCT.app"
