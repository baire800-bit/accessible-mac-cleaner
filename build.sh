#!/bin/bash
# Builds "Accessible Mac Cleaner.app" in this folder. Needs Apple's Command Line Tools (xcode-select --install).
# Most people should use install.sh instead, which downloads a ready-made copy.
set -e
cd "$(dirname "$0")"
A="Accessible Mac Cleaner.app"; R="$A/Contents/Resources"
rm -rf "$A"
osacompile -o "$A" app.applescript
swiftc -O -parse-as-library picker.swift -o "$R/list-apps"          # lists your apps with size, kind and last use
cp clean.sh "$R/clean.sh"; chmod +x "$R/clean.sh"
# The one window you use: questions, lists, progress and Stop
W="$R/Accessible Mac Cleaner Status.app"; mkdir -p "$W/Contents/MacOS" "$W/Contents/Resources"
swiftc -O -parse-as-library status.swift -o "$W/Contents/MacOS/status"
cat > "$W/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>status</string>
<key>CFBundleIdentifier</key><string>io.github.accessible-mac-cleaner.status</string>
<key>CFBundleName</key><string>Accessible Mac Cleaner</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$(cat VERSION)</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
cp AppIcon.icns "$W/Contents/Resources/AppIcon.icns"
cp AppIcon.icns "$R/applet.icns"; rm -f "$R/Assets.car"
P="$A/Contents/Info.plist"
plutil -remove CFBundleIconName "$P" 2>/dev/null || true
# macOS shows CFBundleName in its permission alerts; osacompile leaves it as "applet"
plutil -replace CFBundleName -string "Accessible Mac Cleaner" "$P"
plutil -replace CFBundleIdentifier -string "io.github.accessible-mac-cleaner" "$P"
plutil -replace CFBundleShortVersionString -string "$(cat VERSION)" "$P"
# The script itself stays out of the Dock and Command-Tab; the one window is what you switch to
plutil -replace LSUIElement -bool true "$P"
codesign --force --deep --sign - "$A" 2>/dev/null || true
echo "Built: $(pwd)/$A"
