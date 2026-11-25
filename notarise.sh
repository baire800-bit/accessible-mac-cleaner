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
