#!/bin/bash
# Accessible Mac Cleaner engine. The app calls it; you can also run it yourself.
# Commands: measure | clean <item> | free | bigfiles | leftovers <app> | uninstall <app> | backupdrive
set -u
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
C="$HOME/Library/Caches"
# Never cleared: Apple's own caches, iCloud, maps, browser engines for testing tools.
KEEP='^(com\.apple\..*|CloudKit|GeoServices|ms-playwright|Homebrew)$'

kb(){ [ $# -eq 0 ] && { echo 0; return; }; du -sk "$@" 2>/dev/null | awk '{s+=$1} END{print s+0}'; }
running(){ lsappinfo list 2>/dev/null | sed -n 's/.*bundleID="\([^"]*\)".*/\1/p' | tr 'A-Z' 'a-z' | sort -u; }
cachelist(){
  local run; run=$(running)
  ls -A "$C" 2>/dev/null | grep -Ev "$KEEP" | while IFS= read -r d; do
    low=$(printf '%s' "$d" | tr 'A-Z' 'a-z')
    printf '%s\n' "$run" | grep -qxF "$low" && continue   # skip caches of apps that are open
    printf '%s\n' "$C/$d"
  done
}
totrash(){ # move to the Bin without overwriting anything already there
  local src="$1" base dest; base=$(basename "$src"); dest="$HOME/.Trash/$base"
  [ -e "$dest" ] && dest="$HOME/.Trash/$base $(date +%Y-%m-%d\ %H.%M.%S)"
  mv "$src" "$dest"
}
olddownloads(){ find "$HOME/Downloads" -maxdepth 1 -mindepth 1 -mtime +90 2>/dev/null; }
bundleid(){ defaults read "$1/Contents/Info" CFBundleIdentifier 2>/dev/null; }
leftovers(){
  local app="$1" id nm L="$HOME/Library"; id=$(bundleid "$app"); nm=$(basename "$app" .app)
  [ -n "$id" ] && for p in "Application Support/$id" "Caches/$id" "Containers/$id" "HTTPStorages/$id" "WebKit/$id" \
      "Saved Application State/$id.savedState" "Preferences/$id.plist" "Logs/$id"; do
    [ -e "$L/$p" ] && echo "$L/$p"; done
  [ -n "$nm" ] && [ -e "$L/Application Support/$nm" ] && echo "$L/Application Support/$nm"
  true
}

case "${1:-}" in
measure)
  IFS=$'\n'
  echo "caches|$(kb $(cachelist))|App caches, for apps that are not open (apps rebuild them as needed)"
  echo "logs|$(kb "$HOME/Library/Logs")|Old log files"
  dev=0; command -v brew >/dev/null && dev=$(kb "$(brew --cache)"); dev=$((dev + $(kb "$HOME/.npm/_cacache")))
  echo "dev|$dev|Developer download caches (Homebrew, npm, pnpm, pip)"
  echo "bin|$(kb "$HOME/.Trash")|Items in your Bin"
  echo "downloads|$(kb $(olddownloads))|$(olddownloads | wc -l | tr -d ' ') items in Downloads untouched for 90 days (they go to the Bin, not deleted)"
  echo "snapshots|$(tmutil listlocalsnapshots / 2>/dev/null | grep -c TimeMachine)|Time Machine snapshots stored on this Mac"
  ;;
clean)
  case "${2:-}" in
    caches) IFS=$'\n'; for d in $(cachelist); do rm -rf "$d"; done ;;
    logs) find "$HOME/Library/Logs" -type f -delete 2>/dev/null ;;
    dev) command -v brew >/dev/null && brew cleanup -s --prune=all >/dev/null 2>&1
         command -v npm >/dev/null && npm cache clean --force >/dev/null 2>&1
         command -v pnpm >/dev/null && pnpm store prune >/dev/null 2>&1
         command -v pip3 >/dev/null && pip3 cache purge >/dev/null 2>&1 ;;
    bin) find "$HOME/.Trash" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null ;;
    downloads) olddownloads | while IFS= read -r f; do totrash "$f"; done ;;
    snapshots) tmutil thinlocalsnapshots / 999999999999 4 >/dev/null 2>&1 ;;
  esac; true ;;
free) diskutil info /System/Volumes/Data | awk -F'[:(]' '/Container Free Space/{gsub(/ /,"",$2); print $2}' ;;
backupdrive) # prints "ok" if a Time Machine drive is reachable now, else "missing"
  tmutil latestbackup 2>/dev/null | grep -q "^/" && echo ok || echo missing ;;
bigfiles)
  # bigfiles start | <phase> | finish. Read only: lists files over 1 GB, never deletes.
  out="$HOME/Documents/Big files on this Mac.txt"
  H="$HOME"
  describe(){ # one file -> a short plain description
    local f="$1" sz kind used mod rel note
    sz=$(du -h "$f" 2>/dev/null | cut -f1 | sed -E 's/([0-9.]+)G$/\1 GB/; s/([0-9.]+)M$/\1 MB/')
    kind=$(mdls -raw -name kMDItemKind "$f" 2>/dev/null); [ -z "$kind" ] || [ "$kind" = "(null)" ] && kind=$(file -b "$f" | cut -d, -f1)
    used=$(mdls -raw -name kMDItemLastUsedDate "$f" 2>/dev/null)
    mod=$(stat -f '%Sm' -t '%e %B %Y' "$f" | tr -s ' ' | sed 's/^ //')
    rel="${f#$H/}"; rel=$(dirname "$rel"); [ "$rel" = "." ] && rel="your home folder"
    echo "$sz: $(basename "$f")"
    echo "  Where: $rel"
    if [ -n "$used" ] && [ "$used" != "(null)" ]; then
      ud=$(date -j -f '%Y-%m-%d %H:%M:%S %z' "$used" '+%e %B %Y' 2>/dev/null | tr -s ' ' | sed 's/^ //')
      echo "  What: $kind. Last opened $ud. Last changed $mod."
      age=$(( ( $(date +%s) - $(date -j -f '%Y-%m-%d %H:%M:%S %z' "$used" +%s 2>/dev/null || date +%s) ) / 86400 ))
      [ "$age" -gt 365 ] && note="Not opened in over a year."
    else
      echo "  What: $kind. Never opened, or not recorded. Last changed $mod."
    fi
    case "$f" in
      */Library/*|*/.*/*) note="Inside app data, usually needed by an app. Remove it through the app, or uninstall the app, rather than deleting it by hand." ;;
      "$H/Downloads/"*) note="${note:+$note }In Downloads: often safe to delete once you have kept what you need." ;;
    esac
    [ -n "${note:-}" ] && echo "  Note: $note"
    echo
  }
  scan(){ find "$@" -xdev -type f -size +1G -not -path "*/Library/Mobile Documents/*" -not -path "*/.Trash/*" 2>/dev/null; }
  case "${2:-}" in
    start) { echo "Files over 1 GB on this Mac, $(date '+%e %B %Y')."
             echo "Nothing has been deleted. This is a list to help you decide."; echo; } > "$out" ;;
    desktop) L=$(scan "$H/Desktop") ;;
    documents) L=$(scan "$H/Documents") ;;
    downloads) L=$(scan "$H/Downloads") ;;
    media) L=$(scan "$H/Pictures" "$H/Movies" "$H/Music") ;;
    rest) L=$(find "$H" -xdev -type f -size +1G -not -path "$H/Desktop/*" -not -path "$H/Documents/*" -not -path "$H/Downloads/*" \
            -not -path "$H/Pictures/*" -not -path "$H/Movies/*" -not -path "$H/Music/*" -not -path "*/Library/Mobile Documents/*" -not -path "*/.Trash/*" 2>/dev/null) ;;
    finish) grep -q '^  Where:' "$out" || echo "No files over 1 GB found." >> "$out"; echo "$out" ;;
  esac
  if [ -n "${L:-}" ]; then
    printf '%s\n' "$L" | while IFS= read -r f; do [ -n "$f" ] && printf '%s\t%s\n' "$(du -k "$f" | cut -f1)" "$f"; done | sort -rn | cut -f2- |
      while IFS= read -r f; do describe "$f"; done >> "$out"
  fi ;;
leftovers) leftovers "$2" ;;
uninstall)
  app="$2"; [ -d "$app" ] || exit 2
  list=$(leftovers "$app")
  osascript -e "quit app id \"$(bundleid "$app")\"" >/dev/null 2>&1
  totrash "$app" 2>/dev/null || exit 3          # 3 = needs an administrator password
  printf '%s\n' "$list" | while IFS= read -r f; do [ -n "$f" ] && totrash "$f"; done
  echo ok ;;
*) echo "usage: clean.sh measure | clean <caches|logs|dev|bin|downloads|snapshots> | free | bigfiles | leftovers <app> | uninstall <app> | backupdrive"; exit 1 ;;
esac
