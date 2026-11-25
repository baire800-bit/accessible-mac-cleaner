# Changes

## 1.2.2, 25 November 2026

- A proper installer: download Accessible-Mac-Cleaner.pkg and open it. The Installer app talks you through each step and puts the app in your Applications folder. Signed and notarised by Apple.
- Big files list: no more files showing as 0 bytes. Cloud files that are online only (Dropbox, OneDrive, Google Drive) and sparse files such as virtual machine disks take little or no room on the Mac, so they are left out; only files really using over 1 GB are listed. Downloaded cloud files get a note to make them online only rather than delete them. Reported by Casey Reeves.

## 1.2.1, 24 November 2026

- Signed with a Developer ID and notarised by Apple, so a browser download opens normally on any Mac.
- Runs on macOS 13 Ventura or newer, on Intel and Apple silicon.
- The finished message gives the real amount cleared; only logs older than a week are cleared; open browsers are named.

## 1.2.0, 24 November 2026

The first full release, rebuilt around how VoiceOver users actually work.

- One window for everything, so focus never drops to Finder and only one app shows in Command-Tab.
- Each message is a read-only field VoiceOver reads first; every screen says the keys to use; Down Arrow,
  arrows between buttons, Tab and Return all work. Messages are read once, from their first word.
- Clean up space is one ticked list with plain warnings, then a single summary.
- Uninstall apps: choose the order, tick apps in the same window, plain-English confirmation, back to the menu.
- Big files: one introduction, then it works through five places; each file described.
- macOS permission alerts explained, with a Show the alert button; never skips a folder unless you say.
- Returns to the menu after every job or cancel; Close, Escape or Command-Q to leave.
- Calmer, friendlier wording; a working sound; an app icon; a one-line installer.

## 1.1.0
- Big-files list reads one folder at a time and describes each file.

## 1.0.0
- First version: clean up, uninstall, big files.
