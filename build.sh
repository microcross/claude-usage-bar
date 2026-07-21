#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="UsageWidget.app"
BUNDLE_ID="com.local.usagewidget"
VERSION="1.1.0"

swift build -c release

mkdir -p "$APP/Contents/MacOS"
cp .build/release/UsageWidget "$APP/Contents/MacOS/UsageWidget"

# Generate Info.plist. Without it the bundle has no LSUIElement (would show a
# Dock icon instead of being menu-bar-only) and no bundle identifier (so the
# SMAppService login-item registration in the app silently fails).
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>UsageWidget</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>UsageWidget</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# Ad-hoc code signature so SMAppService (login item) and WKWebView behave.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP — run 'open $APP' or double-click it in Finder."
