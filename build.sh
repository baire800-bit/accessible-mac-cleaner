#!/bin/bash
# Builds "Accessible Mac Cleaner.app" in this folder. Needs Apple's Command Line Tools (xcode-select --install).
# Most people should use install.sh instead, which downloads a ready-made copy.
set -e
cd "$(dirname "$0")"
A="Accessible Mac Cleaner.app"; R="$A/Contents/Resources"
rm -rf "$A"
osacompile -o "$A" app.applescript
# Build for every Mac from macOS 13 Ventura up, Intel and Apple silicon alike (not just the Mac building it)
SDK=$(xcrun --show-sdk-path)
uni(){ # uni <source> <output>
  swiftc -O -parse-as-library -target arm64-apple-macos13.0 -sdk "$SDK" "$1" -o "$2.arm64"
  swiftc -O -parse-as-library -target x86_64-apple-macos13.0 -sdk "$SDK" "$1" -o "$2.x86_64"
  lipo -create "$2.arm64" "$2.x86_64" -output "$2"; rm -f "$2.arm64" "$2.x86_64"
}
# osacompile copies this Mac's own launcher, marked for this macOS only; it uses nothing newer than 13
vtool -set-build-version macos 13.0 "$(xcrun --show-sdk-version)" -replace -output "$A/Contents/MacOS/applet.new" "$A/Contents/MacOS/applet" 2>/dev/null \
  && mv "$A/Contents/MacOS/applet.new" "$A/Contents/MacOS/applet"
uni picker.swift "$R/list-apps"          # lists your apps with size, kind and last use
cp clean.sh "$R/clean.sh"; chmod +x "$R/clean.sh"
# The one window you use: questions, lists, progress and Stop
W="$R/Accessible Mac Cleaner Status.app"; mkdir -p "$W/Contents/MacOS" "$W/Contents/Resources"
uni status.swift "$W/Contents/MacOS/status"
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
# Sign: Developer ID (Apple-issued, notarisable) if this Mac has it, else the old fixed identity, else ad hoc.
DEVID=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/{print $2; exit}')
if [ -n "$DEVID" ]; then
  # inside-out, hardened runtime and a secure timestamp, as notarisation requires
  for f in "$R/list-apps" "$W"; do codesign --force --options runtime --timestamp --sign "$DEVID" "$f"; done
  codesign --force --options runtime --timestamp --entitlements entitlements.plist --sign "$DEVID" "$A"
else
  SIGN=$(security find-certificate -c "Barry Toner Apps" -Z 2>/dev/null | awk '/SHA-1/{print $3}')
  codesign --force --deep --sign "${SIGN:--}" "$A" 2>/dev/null || codesign --force --deep --sign - "$A"
fi
echo "Built: $(pwd)/$A"
