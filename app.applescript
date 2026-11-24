-- Accessible Mac Cleaner: every step is a standard dialog or list, so VoiceOver reads it all.
property appTitle : "Accessible Mac Cleaner"
on eng()
	return POSIX path of (path to me) & "Contents/Resources/clean.sh"
end eng
on sh(a)
	return do shell script "/bin/bash " & quoted form of eng() & " " & a
end sh
on gb(k)
	set k to k as number
	if k < 1048576 then return ((round (k / 1024)) as string) & " MB"
	return ((round (k / 104857.6)) / 10 as string) & " GB"
end gb
on askUser(msg, yesLabel)
	return button returned of (display dialog msg buttons {"Skip", yesLabel} default button yesLabel with title appTitle)
end askUser
on run
	set startFree to sh("free")
	set choice to choose from list {"Clean up space", "Uninstall an app", "List my biggest files (read only, nothing is deleted)"} with title appTitle with prompt "Free space now: " & startFree & ". What would you like to do?" default items {"Clean up space"}
	if choice is false then return
	set choice to item 1 of choice
	if choice is "Clean up space" then
		display dialog "Measuring. This can take a minute." buttons {"OK"} default button 1 giving up after 2 with title appTitle
		set lns to paragraphs of sh("measure")
		repeat with itemKey in {"caches", "logs", "dev", "bin", "downloads", "snapshots"}
			repeat with l in lns
				set AppleScript's text item delimiters to "|"
				set p to text items of l
				set AppleScript's text item delimiters to ""
				if item 1 of p is (itemKey as string) and (item 2 of p as number) > 0 then
					if itemKey as string is "snapshots" then
						set msg to item 3 of p & ": " & item 2 of p & ". Removing them gives back space held by files you have deleted, but you lose those local restore points."
						if sh("backupdrive") is not "ok" then set msg to msg & " Warning: your Time Machine backup drive is not connected right now, so these snapshots may be your only recent backup. Consider connecting the drive first."
						set r to askUser(msg, "Remove")
					else if itemKey as string is "bin" then
						set r to askUser(item 3 of p & ": " & gb(item 2 of p) & ". Emptying the Bin cannot be undone.", "Empty")
					else
						set r to askUser(item 3 of p & ": " & gb(item 2 of p) & ".", "Clean")
					end if
					if r is not "Skip" then sh("clean " & itemKey)
				end if
			end repeat
		end repeat
		set endFree to sh("free")
		display dialog "Done. Free space was " & startFree & ", now " & endFree & "." buttons {"OK"} default button 1 with title appTitle
	else if choice is "Uninstall an app" then
		set apps to paragraphs of (do shell script "ls /Applications | grep '\\.app$' | sed 's/\\.app$//'")
		set pick to choose from list apps with title appTitle with prompt "Which app do you want to uninstall?"
		if pick is false then return
		set appPath to "/Applications/" & (item 1 of pick) & ".app"
		set extra to sh("leftovers " & quoted form of appPath)
		set sz to do shell script "{ du -sk " & quoted form of appPath & "; printf '%s\\n' " & quoted form of extra & " | while IFS= read -r f; do [ -n \"$f\" ] && du -sk \"$f\"; done; } 2>/dev/null | awk '{s+=$1} END{print s+0}'"
		set n to 0
		if extra is not "" then set n to count of paragraphs of extra
		set listing to ""
		if n > 0 then set listing to " Leftover files: " & linefeed & extra
		set r to button returned of (display dialog "Move " & (item 1 of pick) & " and " & n & " leftover items to the Bin? About " & gb(sz) & "." & listing buttons {"Cancel", "Uninstall"} default button "Cancel" with title appTitle)
		if r is "Uninstall" then
			try
				sh("uninstall " & quoted form of appPath)
				display dialog (item 1 of pick) & " is in the Bin. Empty the Bin to get the space back." buttons {"OK"} default button 1 with title appTitle
			on error
				display dialog (item 1 of pick) & " needs your administrator password to remove. macOS will ask for it next." buttons {"Cancel", "Continue"} default button "Continue" with title appTitle
				set trashDest to POSIX path of (path to home folder) & ".Trash/" & (item 1 of pick) & ".app"
				do shell script "mv " & quoted form of appPath & " " & quoted form of trashDest with administrator privileges
				if extra is not "" then do shell script "printf '%s\\n' " & quoted form of extra & " | while IFS= read -r f; do [ -n \"$f\" ] && mv \"$f\" ~/.Trash/ ; done; true"
				display dialog (item 1 of pick) & " is in the Bin." buttons {"OK"} default button 1 with title appTitle
			end try
		end if
	else
		display dialog "This only makes a list of files over 1 GB, with where they are and when you last opened them. Nothing is deleted or moved." & linefeed & linefeed & "It looks in five places, one at a time. For some of them macOS may ask whether this app can access that folder. Allow lets it list big files there. Don't Allow just skips that folder." buttons {"Cancel", "Start"} default button "Start" with title appTitle
		sh("bigfiles start")
		repeat with ph in {{"desktop", "your Desktop"}, {"documents", "your Documents folder"}, {"downloads", "your Downloads folder"}, {"media", "your Pictures, Movies and Music folders"}, {"rest", "the rest of your home folder, including app data. This one takes longest"}}
			display dialog "Now looking in " & item 2 of ph & ". If macOS asks for access, it is only to list big files. Nothing is deleted." buttons {"OK"} default button 1 giving up after 10 with title appTitle
			sh("bigfiles " & item 1 of ph)
		end repeat
		set f to sh("bigfiles finish")
		display dialog "Done. The list is open in TextEdit, and saved in Documents as Big files on this Mac." buttons {"OK"} default button 1 giving up after 10 with title appTitle
		do shell script "open -a TextEdit " & quoted form of f
	end if
end run
