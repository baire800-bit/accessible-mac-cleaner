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
  out="$HOME/Documents/Big files on this Mac.txt"
  { echo "Files over 1 GB in your home folder, biggest first. $(date '+%d %B %Y')"; echo
    find "$HOME" -xdev -type f -size +1G -not -path "*/Library/Mobile Documents/*" -not -path "*/.Trash/*" 2>/dev/null -exec du -h {} + | sort -rh; } > "$out"
  echo "$out" ;;
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
