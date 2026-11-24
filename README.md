# Accessible Mac Cleaner

A free Mac cleaner made for VoiceOver from the ground up. It clears space, uninstalls apps along with their
leftover files, and finds your biggest files, and every step talks to you clearly.

It was designed with and tested by a VoiceOver user, screen by screen.

## Install

Open Terminal (press Command-Space, type Terminal, press Return), paste this line, and press Return:

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/baire800-bit/accessible-mac-cleaner/main/install.sh)"

The installer tells you each step, puts the app in your Applications folder and opens it. It takes a few
seconds and needs nothing else installed. Works on macOS 13 Ventura or newer, on any Mac.

## Using it

Everything happens in one window, and every screen tells you the keys to use. Focus starts on the message,
so VoiceOver reads it first.

- Down Arrow goes from the message to the choices or buttons. Up and Down Arrow pick a choice, Left and Right
  Arrow move between buttons, Space ticks a box, and Return goes ahead. Tab works everywhere too.
- After each job you come back to the main menu, with your free space updated. Close, Escape or Command-Q
  leaves.
- While it works, it says what it's doing and plays a soft pop every few seconds, with a Stop button.

### Clean up space

It has a quick look, then shows one list of everything it found, with sizes. The safe items are already
ticked: app caches (for apps that aren't open), old log files, and developer download caches. These are left
for you to choose, each with a plain warning: emptying the Bin, moving Downloads untouched for 90 days to the
Bin, and removing Time Machine snapshots stored on the Mac (it tells you if your backup drive isn't
connected). Tick what you want and press Return. At the end it tells you your new free space.

### Uninstall apps

Choose how to list your apps: by name, biggest first, or least recently used first. Each app says its size,
what kind of app it is and when you last used it. Tick any you want gone, and it tells you how many leftover
files it found and the total size before anything happens. Everything goes to the Bin, so you can change your
mind. If an app needs your administrator password, macOS asks for it once.

### List my biggest files

Makes a list of every file over 1 GB in your home folder: where it is, what it is, when you last opened it,
and a short note such as "not opened in over a year". Nothing is deleted. The list opens in TextEdit and is
saved in Documents.

## Permission alerts

The first time the app looks in Downloads, Desktop or Documents, macOS asks whether that's OK. VoiceOver
doesn't always read macOS's alert, so the app explains it and offers a Show the alert button: then Tab to
Allow and press Space. macOS only asks once.

## What it never touches

System files, anything outside your home folder (except an app you choose to uninstall), Apple's own caches,
iCloud's caches, and the hidden .cache folder where tools keep large downloads like speech models.

## Remove it

Drag Accessible Mac Cleaner from Applications to the Bin.

## Build it yourself

With Apple's Command Line Tools installed (`xcode-select --install`), run `./build.sh` in this folder.

## Licence

MIT. See LICENSE. Made by Barry Toner, with Claude.
