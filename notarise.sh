#!/bin/bash
# Build, notarise with Apple and staple, then make the release zip. Needs the "barry-notary" keychain profile.
set -e
cd "$(dirname "$0")"
./build.sh
A="Accessible Mac Cleaner.app"
rm -f upload.zip; ditto -c -k --keepParent "$A" upload.zip
xcrun notarytool submit upload.zip --keychain-profile barry-notary --wait
xcrun stapler staple "$A"
rm -f upload.zip Accessible-Mac-Cleaner.zip; ditto -c -k --keepParent "$A" Accessible-Mac-Cleaner.zip
spctl -a -vv -t exec "$A"

# The installer package (.pkg): the friendliest route with a screen reader, since the Installer app reads out
# every step and puts the app in Applications itself. Needs the "Developer ID Installer" certificate.
PKG="Accessible-Mac-Cleaner.pkg"; ROOT=$(mktemp -d); mkdir -p "$ROOT/Applications"; ditto "$A" "$ROOT/Applications/$A"
# Not relocatable: otherwise Installer "updates" a copy found elsewhere (say in Downloads) instead of Applications.
pkgbuild --analyze --root "$ROOT" comp.plist; plutil -replace 0.BundleIsRelocatable -bool NO comp.plist
pkgbuild --root "$ROOT" --component-plist comp.plist --identifier com.barrytoner.accessiblemaccleaner.pkg --version "$(cat VERSION)" --install-location / component.pkg
productbuild --package component.pkg --sign "Developer ID Installer: Barry Toner (M5X68AWLJ6)" --timestamp "$PKG"
rm -rf "$ROOT" component.pkg comp.plist
xcrun notarytool submit "$PKG" --keychain-profile barry-notary --wait
xcrun stapler staple "$PKG"
spctl -a -vv -t install "$PKG"
