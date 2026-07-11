#!/bin/bash
set -e

APP_NAME="Codex-Usage"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
RESOURCE_BUNDLE="$BUILD_DIR/Codex-Usage_Codex-Usage.bundle"

swift build -c release

if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "Required resource bundle not found: $RESOURCE_BUNDLE"
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
if [ -f "Sources/Codex-Usage/Resources/AppIcon.icns" ]; then
    cp "Sources/Codex-Usage/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.codexusage.Codex-Usage</string>
    <key>CFBundleName</key>
    <string>Codex-Usage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.1</string>
    <key>CFBundleVersion</key>
    <string>1.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
echo "Run './Scripts/install.sh' to copy it to /Applications."
