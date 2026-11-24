# Accessible Mac Cleaner

A small, free Mac cleaner built to work fully with VoiceOver. Every step is a standard macOS dialog or list,
so a screen reader reads all of it. There is no custom window to fight with.

It does the space-saving jobs that paid cleaners do:

- Clean up space: measures, then asks about each item one at a time, with its size, before touching it.
  - App caches, skipping Apple's own caches and the caches of any app that is open
  - Old log files
  - Developer download caches (Homebrew, npm, pnpm, pip), if you have those tools
  - The Bin
  - Items in Downloads untouched for 90 days (moved to the Bin, never deleted outright)
  - Time Machine snapshots stored on the Mac itself. It warns you if your backup drive is not connected,
    because then those snapshots may be your only recent backup.
- Uninstall an app: lists the app's leftover files by exact name, tells you the total size, and moves
  everything to the Bin so you can change your mind. If the app needs an administrator password to remove,
  macOS asks for it in its own dialog.
- List my biggest files: writes every file over 1 GB in your home folder to a text file in Documents and
  opens it in TextEdit.

At the end of a clean-up it tells you the free space before and after.

## What it never touches

System files, anything outside your home folder (except the app you choose to uninstall), Apple's caches,
iCloud's caches, and the `~/.cache` folder, where tools such as speech-recognition models keep large
downloads you would have to fetch again.

## Install

You need a Mac with macOS 13 or later. Download or clone this repository, then run:

    ./build.sh

That builds `Accessible Mac Cleaner.app` in the same folder. Move it to Applications if you like.
Because you build it yourself, macOS does not show the "unidentified developer" warning.

The engine is `clean.sh`. You can run it directly too: `./clean.sh measure` shows what it would clean
without changing anything.

## Safety

Caches and logs are rebuilt by apps as needed, so clearing them is normally harmless, but an app may be
slower the first time you open it afterwards. Emptying the Bin and removing Time Machine snapshots cannot be
undone, and the app says so before it does either. Use it at your own risk; see the licence.

## Licence

MIT. See LICENSE.
