#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-$PWD/build/Quick Copy.app}"
mkdir -p "$APP/Contents/MacOS"
swiftc -target "$(uname -m)-apple-macosx13.0" -module-cache-path /private/tmp/quickcopy-module-cache Sources/QuickCopy.swift -o "$APP/Contents/MacOS/Quick Copy" -framework AppKit -framework SwiftUI
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Quick Copy</string>
<key>CFBundleDisplayName</key><string>Quick Copy</string>
<key>CFBundleIdentifier</key><string>com.local.quickcopy</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleExecutable</key><string>Quick Copy</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP" >/dev/null
printf 'Built %s\n' "$APP"
