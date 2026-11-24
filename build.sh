#!/bin/bash
# Builds "Accessible Mac Cleaner.app" in this folder. Copy it to Applications if you like.
set -e
cd "$(dirname "$0")"
rm -rf "Accessible Mac Cleaner.app"
osacompile -o "Accessible Mac Cleaner.app" app.applescript
cp clean.sh "Accessible Mac Cleaner.app/Contents/Resources/clean.sh"
chmod +x "Accessible Mac Cleaner.app/Contents/Resources/clean.sh"
codesign --force --sign - "Accessible Mac Cleaner.app" 2>/dev/null || true
echo "Built: $(pwd)/Accessible Mac Cleaner.app"
