#!/bin/bash
# Accessible Mac Cleaner installer. Run it in Terminal with:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/baire800-bit/accessible-mac-cleaner/main/install.sh)"
# It downloads the latest release, puts it in your Applications folder and opens it. Nothing else is changed.
set -e
APP="Accessible Mac Cleaner"
ZIP_URL="https://github.com/baire800-bit/accessible-mac-cleaner/releases/latest/download/Accessible-Mac-Cleaner.zip"
say_line(){ printf '%s\n' "$1"; }
say_line "Installing $APP."
v=$(sw_vers -productVersion | cut -d. -f1)
if [ "$v" -lt 13 ]; then say_line "Sorry, $APP needs macOS 13 Ventura or newer. This Mac has macOS $(sw_vers -productVersion)."; exit 1; fi
T=$(mktemp -d)
say_line "Downloading the latest version."
curl -fsSL -o "$T/app.zip" "$ZIP_URL" || { say_line "Sorry, the download didn't work. Check you're online and try again."; exit 1; }
ditto -x -k "$T/app.zip" "$T"
[ -d "$T/$APP.app" ] || { say_line "Sorry, the download wasn't what I expected. Please try again later."; exit 1; }
if pgrep -f "$APP.app/Contents" >/dev/null; then say_line "Closing the copy that's open."; pkill -f "$APP.app/Contents" || true; sleep 1; fi
DEST="/Applications"; [ -w "$DEST" ] || DEST="$HOME/Applications"; mkdir -p "$DEST"
rm -rf "$DEST/$APP.app"
ditto "$T/$APP.app" "$DEST/$APP.app"
xattr -dr com.apple.quarantine "$DEST/$APP.app" 2>/dev/null || true
rm -rf "$T"
say_line "Done. $APP is in your $( [ "$DEST" = /Applications ] && echo Applications folder || echo own Applications folder ), and it's opening now."
say_line "Next time, open it from Spotlight: press Command-Space, type Accessible Mac Cleaner, and press Return."
open "$DEST/$APP.app"
