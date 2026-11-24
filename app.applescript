-- Accessible Mac Cleaner: every step happens in one accessible window (status.swift), so any screen reader reads it.
property appTitle : "Accessible Mac Cleaner"
on eng()
	return POSIX path of (path to me) & "Contents/Resources/clean.sh"
end eng
property statusFile : ""
property askCount : 0
on helperPath()
	return POSIX path of (path to me) & "Contents/Resources/Accessible Mac Cleaner Status.app"
end helperPath
on windowAppID()
	if appTitle is "Video Reader" then return "io.github.video-reader.window"
	return "io.github.accessible-mac-cleaner.status"
end windowAppID
on sendCmd(c)
	-- One window (the helper) is open for the whole run. Commands are added to a file, one per line,
	-- and the window works through them in order. Line breaks inside a message travel as \n.
	set AppleScript's text item delimiters to linefeed
	set parts to text items of c
	set AppleScript's text item delimiters to "\\n"
	set c to parts as string
	set AppleScript's text item delimiters to ""
	if statusFile is "" then
		set statusFile to do shell script "mktemp -t amc-session"
		do shell script "printf '%s\\n' " & quoted form of c & " >> " & quoted form of statusFile
		-- Make sure macOS knows the window app by name, or Command-Tab can't switch to it
		do shell script "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f " & quoted form of helperPath() & " >/dev/null 2>&1; true"
		do shell script "open -n " & quoted form of helperPath() & " --args --session " & quoted form of statusFile & " " & quoted form of appTitle
		-- Hand the front over to the window we just opened (macOS only allows it from the app you launched)
		repeat with i from 1 to 10
			delay 0.2
			try
				do shell script "pgrep -f -- " & quoted form of ("--session " & statusFile)
				exit repeat
			end try
		end repeat
		try
			tell application id (my windowAppID()) to activate
		end try
	else
		do shell script "printf '%s\\n' " & quoted form of c & " >> " & quoted form of statusFile
	end if
end sendCmd
on status(t)
	sendCmd("STATUS" & tab & t)
end status
on closeStatus()
	if statusFile is not "" then
		do shell script "printf 'CLOSE\\n' >> " & quoted form of statusFile & "; sleep 0.8; rm -f " & quoted form of statusFile & "*"
		set statusFile to ""
	end if
end closeStatus
on indexOf(k)
	if k is "desktop" then return 1
	if k is "documents" then return 2
	return 3
end indexOf
on doneLine(chosen, keyList, sizeList, endFree)
	set clearedK to 0
	set snaps to false
	repeat with k in chosen
		if (k as string) is "snapshots" then set snaps to true
		repeat with i from 1 to count of keyList
			if item i of keyList is (k as string) then set clearedK to clearedK + (item i of sizeList)
		end repeat
	end repeat
	set t to "All done. I cleared about " & gb(clearedK)
	if snaps then set t to t & " and removed the Time Machine snapshots"
	return t & ". You now have " & endFree & " free."
end doneLine
on nameFor(k)
	if k is "caches" then return "app caches"
	if k is "browsers" then return "web browser caches"
	if k is "logs" then return "old log files"
	if k is "dev" then return "developer caches"
	if k is "bin" then return "emptying the Bin"
	if k is "downloads" then return "moving old downloads to the Bin"
	return "Time Machine snapshots"
end nameFor
on askMenu(msg, opts)
	set askCount to askCount + 1
	set c to "MENU" & tab & askCount & tab & msg
	repeat with o in opts
		set c to c & tab & (o as string)
	end repeat
	sendCmd(c)
	set f to statusFile & ".answer." & askCount
	repeat
		delay 0.3
		set ans to do shell script "cat " & quoted form of f & " 2>/dev/null; true"
		if ans is not "" then exit repeat
		if (do shell script "pgrep -f -- " & quoted form of ("--session " & statusFile) & " >/dev/null && echo y || echo n") is "n" then
			error number 1001
		end if
	end repeat
	do shell script "rm -f " & quoted form of f
	if ans is "Cancel" then
		error number -128
	end if
	return ans
end askMenu
on askDlg(msg, btns, def)
	-- Ask in the same window: the message is a read-only field Tab reaches, then the buttons.
	set askCount to askCount + 1
	set c to "ASK" & tab & askCount & tab & def & tab & msg
	repeat with b in btns
		set c to c & tab & (b as string)
	end repeat
	sendCmd(c)
	set f to statusFile & ".answer." & askCount
	repeat
		delay 0.3
		set ans to do shell script "cat " & quoted form of f & " 2>/dev/null; true"
		if ans is not "" then exit repeat
		if (do shell script "pgrep -f -- " & quoted form of ("--session " & statusFile) & " >/dev/null && echo y || echo n") is "n" then
			error number 1001
		end if
	end repeat
	do shell script "rm -f " & quoted form of f
	if ans is "Cancel" then
		error number -128
	end if
	return ans
end askDlg
on askAccess(folderPath)
	try
		sh("access " & quoted form of folderPath)
		return true
	on error m number n
		if n is -128 then error number -128
		return false
	end try
end askAccess
on sh(a)
	-- The window's own app runs the engine, so any macOS permission alert belongs to the app in front,
	-- and this script keeps answering VoiceOver while it waits.
	set askCount to askCount + 1
	set argText to do shell script "eval 'set -- '" & quoted form of a & "; printf '%s\\t' \"$@\""
	if argText ends with tab then set argText to text 1 thru -2 of argText
	sendCmd("RUN" & tab & askCount & tab & argText)
	set f to statusFile & ".answer." & askCount
	repeat
		delay 0.4
		if (do shell script "test -f " & quoted form of f & " && echo y || echo n") is "y" then exit repeat
		if (do shell script "test -f " & quoted form of (statusFile & ".stop") & " && echo y || echo n") is "y" then
			error number -128
		end if
		if (do shell script "pgrep -f -- " & quoted form of ("--session " & statusFile) & " >/dev/null && echo y || echo n") is "n" then error number 1001
	end repeat
	set res to do shell script "cat " & quoted form of f & "; rm -f " & quoted form of f without altering line endings
	set rc to paragraph 1 of res
	if (length of res) > ((length of rc) + 1) then
		set res to text ((length of rc) + 2) thru -1 of res
	else
		set res to ""
	end if
	if res ends with linefeed then set res to text 1 thru -2 of res
	if rc is not "0" then error res number (rc as integer)
	return res
end sh
on gb(k)
	set k to k as number
	if k < 1048576 then return ((round (k / 1024)) as string) & " MB"
	return ((round (k / 104857.6)) / 10 as string) & " GB"
end gb
on askUser(msg, yesLabel)
	return askDlg(msg, {"Skip", yesLabel}, yesLabel)
end askUser
on run
	try
		mainRun()
	on error m number n
		closeStatus()
		if n is not -128 and n is not 1001 then display alert "Sorry, something went wrong" message m
	end try
end run

on mainRun()
	-- The menu comes back after each job, or when you cancel one. Close (or Command-Q) leaves.
	repeat
			set startFree to do shell script "/bin/bash " & quoted form of eng() & " free"
			set choice to askMenu("Hello. You have " & startFree & " free on this Mac. What would you like to do? To choose, press Down Arrow to go to the choices, use Up and Down Arrow to pick one, then press Return.", {"Clean up space", "Uninstall apps", "List my biggest files"})
			if choice is "Close" then exit repeat
		try
		if choice is "Clean up space" then
				askAccess(POSIX path of (path to downloads folder))
				status("Having a look at what can be cleared. This only takes a few seconds.")
				set lns to paragraphs of sh("measure")
				set cleanItems to {}
				set labels to {"caches", "browsers", "logs", "dev", "bin", "downloads", "snapshots"}
		set openBrowsers to ""
		set keyList to {}
		set sizeList to {}
				set foundK to 0
				repeat with itemKey in labels
					set k to itemKey as string
					repeat with l in lns
						set AppleScript's text item delimiters to "|"
						set p to text items of l
						set AppleScript's text item delimiters to ""
						if item 1 of p is k then
							set n to item 2 of p as number
							if k is "browsers" and (count of p) > 3 then set openBrowsers to item 4 of p
							if k is "snapshots" and n > 0 then
								set lab to (n as string) & " Time Machine snapshots stored on this Mac. They hold space used by files you've deleted."
								if sh("backupdrive") is not "ok" then set lab to lab & " Your backup drive isn't connected, so these may be your only recent backups."
								set end of cleanItems to k & "|" & lab & "|0"
							else if n ≥ 1024 then
								set foundK to foundK + n
								set end of keyList to k
								set end of sizeList to n
								if k is "caches" then set end of cleanItems to k & "|App caches, " & gb(n) & ". Temporary files that apps rebuild when needed.|1"
						if k is "browsers" then set end of cleanItems to k & "|Web browser caches for " & (item 3 of p) & ", " & gb(n) & ". Saved copies of web pages; sites may load a little slower the first time afterwards. You stay signed in.|1"
								if k is "logs" then set end of cleanItems to k & "|Old log files, " & gb(n) & ".|1"
								if k is "dev" then set end of cleanItems to k & "|Developer download caches, " & gb(n) & ". Left over from Homebrew, npm and pip.|1"
								if k is "bin" then set end of cleanItems to k & "|Empty the Bin, " & gb(n) & ". This can't be undone.|0"
								if k is "downloads" then set end of cleanItems to k & "|" & (word 1 of (item 3 of p)) & " items in Downloads not opened for 90 days, " & gb(n) & ". They go to the Bin, so you can still get them back.|0"
							end if
						end if
					end repeat
				end repeat
				if cleanItems is {} then
					set lastAns to askDlg("Good news: your Mac's already tidy, so there's nothing worth clearing right now. You have " & startFree & " free.", {"OK"}, "OK")
				else
					set c to "CHECK" & tab
					set askCount to askCount + 1
					set browserNote to ""
			if openBrowsers is not "" then set browserNote to " " & openBrowsers & " is open, so I've left its cache alone; quit it and run this again to clear that too."
			set c to c & askCount & tab & "I found about " & gb(foundK) & " you can clear." & browserNote & " The safe ones are already ticked, and the rest are up to you. Press Down Arrow to go to the list, use Up and Down Arrow to move through it, press Space to tick or untick an item, then press Return to clean." & tab & "Clean ticked items"
					repeat with oneItem in cleanItems
						set c to c & tab & (oneItem as string)
					end repeat
					sendCmd(c)
					set f to statusFile & ".answer." & askCount
					repeat
						delay 0.3
						set ans to do shell script "cat " & quoted form of f & " 2>/dev/null; true" without altering line endings
						if ans is not "" then exit repeat
						if (do shell script "pgrep -f -- " & quoted form of ("--session " & statusFile) & " >/dev/null && echo y || echo n") is "n" then error number 1001
					end repeat
					do shell script "rm -f " & quoted form of f
					if ans is "Cancel" then
						error number -128
					end if
					if ans is "NONE" then
						set lastAns to askDlg("Nothing was ticked, so I've left everything as it was.", {"OK"}, "OK")
					else
						set chosen to paragraphs of ans
						set i to 0
						repeat with k in chosen
							set i to i + 1
							set nm to my nameFor(k as string)
							status("Clearing " & i & " of " & (count of chosen) & ": " & nm & ".")
							sh("clean " & k)
						end repeat
						set endFree to sh("free")
						set lastAns to askDlg(my doneLine(chosen, keyList, sizeList, endFree), {"OK"}, "OK")
					end if
				end if
			else if choice is "Uninstall apps" then
				set sortChoice to askMenu("How would you like your apps listed? To choose, press Down Arrow to go to the choices, use Up and Down Arrow to pick one, then press Return.", {"By name", "Biggest first", "Least recently used first"})
		set sortKey to "name"
		if sortChoice is "Biggest first" then set sortKey to "size"
		if sortChoice is "Least recently used first" then set sortKey to "used"
		status("Gathering your apps. Each one tells you its size, what it is and when you last used it.")
		set appLines to paragraphs of (do shell script quoted form of (POSIX path of (path to me) & "Contents/Resources/list-apps") & " --items " & sortKey)
		set askCount to askCount + 1
		set c to "CHECK" & tab & askCount & tab & "Here are your apps. Press Down Arrow to go to the list, use Up and Down Arrow to move through it, press Space to tick any you'd like to uninstall, then press Return. Nothing's removed until you confirm." & tab & "Uninstall ticked apps"
		repeat with oneLine in appLines
			set c to c & tab & (oneLine as string)
		end repeat
		sendCmd(c)
		set f to statusFile & ".answer." & askCount
		repeat
			delay 0.3
			set picked to do shell script "cat " & quoted form of f & " 2>/dev/null; true" without altering line endings
			if picked is not "" then exit repeat
			if (do shell script "pgrep -f -- " & quoted form of ("--session " & statusFile) & " >/dev/null && echo y || echo n") is "n" then error number 1001
		end repeat
		do shell script "rm -f " & quoted form of f
		if picked is "Cancel" or picked is "NONE" then error number -128
		set appPaths to paragraphs of picked
				status("Got it. Checking what you ticked and gathering up any leftover files.")
				set totalK to 0
				set nLeft to 0
				set allExtra to {}
				set names to {}
				repeat with ap in appPaths
					set ex to sh("leftovers " & quoted form of ap)
					set end of allExtra to ex
					if ex is not "" then set nLeft to nLeft + (count of paragraphs of ex)
					set totalK to totalK + (do shell script "{ du -sk " & quoted form of ap & "; printf '%s\\n' " & quoted form of ex & " | while IFS= read -r f; do [ -n \"$f\" ] && du -sk \"$f\"; done; } 2>/dev/null | awk '{s+=$1} END{print s+0}'") as number
					set AppleScript's text item delimiters to "/"
					set end of names to text 1 thru -5 of (last text item of ap)
					set AppleScript's text item delimiters to ""
				end repeat
				set AppleScript's text item delimiters to ", "
				set nameList to names as string
				set AppleScript's text item delimiters to ""
				set nApps to count of appPaths
				if nApps is 1 then
					set q to "Uninstall " & nameList & "? " & nameList
				else
					set q to "Uninstall " & nApps & " apps? " & nameList & ","
				end if
				if nLeft is 1 then
					set q to q & " and 1 leftover file"
				else if nLeft > 1 then
					set q to q & " and " & nLeft & " leftover files"
				end if
				set q to q & ", about " & gb(totalK) & ", will go to the Bin, so you can always change your mind. Press Down Arrow to go to the buttons, Left and Right Arrow to move between them, then Return."
				set r to askDlg(q, {"Cancel", "Uninstall"}, "Uninstall")
				if r is not "Uninstall" then
					error number -128
				end if
				if nApps is 1 then
					status("Moving " & nameList & " to the Bin.")
				else
					status("Moving " & nApps & " apps to the Bin.")
				end if
				set needAdmin to {}
				repeat with i from 1 to count of appPaths
					set ap to item i of appPaths
					try
						sh("uninstall " & quoted form of ap)
					on error
						set end of needAdmin to i
					end try
				end repeat
				if needAdmin is not {} then
					set lastAns to askDlg(((count of needAdmin) as string) & " of them need your administrator password to remove. macOS will ask for it once, next.", {"Skip those", "Continue"}, "Continue")
					set skippedNames to {}
					if lastAns is not "Continue" then
						repeat with ii in needAdmin
							set end of skippedNames to item (contents of ii) of names
						end repeat
					end if
					if lastAns is "Continue" then
						set cmd to ""
						repeat with ii in needAdmin
							set i to contents of ii
							set ap to item i of appPaths
							set cmd to cmd & "mv " & quoted form of ap & " " & quoted form of (POSIX path of (path to home folder) & ".Trash/" & (item i of names) & ".app") & "; "
						end repeat
						do shell script cmd & "true" with administrator privileges
						repeat with ii in needAdmin
							set ex to item (contents of ii) of allExtra
							if ex is not "" then do shell script "printf '%s\\n' " & quoted form of ex & " | while IFS= read -r f; do [ -n \"$f\" ] && mv \"$f\" ~/.Trash/ ; done; true"
						end repeat
					end if
				end if
				if needAdmin is not {} and skippedNames is not {} then
					set AppleScript's text item delimiters to ", "
					set skippedText to skippedNames as string
					set AppleScript's text item delimiters to ""
					set lastAns to askDlg("Done, except " & skippedText & ", which I left alone because you chose to skip the ones needing your password. Anything I removed is in the Bin until you empty it.", {"OK"}, "OK")
				else if nApps is 1 then
					set lastAns to askDlg("Done. " & nameList & " is now in the Bin. When you're sure you don't need it, empty the Bin to free up the space.", {"OK"}, "OK")
				else
					set lastAns to askDlg("Done. " & nameList & " are now in the Bin. When you're sure you don't need them, empty the Bin to free up the space.", {"OK"}, "OK")
				end if
			else
				set lastAns to askDlg("I'll make a list of every file over 1 GB, with where it is and when you last opened it. Nothing gets deleted or moved. I'll look in five places, one after another, and if macOS wants to check it's OK for me to look in a folder, I'll tell you.", {"Cancel", "Start"}, "Start")
				sh("bigfiles start")
				repeat with ph in {{"desktop", "your Desktop", true}, {"documents", "your Documents folder", true}, {"downloads", "your Downloads folder", true}, {"media", "your Pictures, Movies and Music folders", false}, {"rest", "the rest of your home folder. This one takes the longest", false}}
					status("Looking in " & item 2 of ph & ".")
					set okToLook to true
					if item 3 of ph then
						set fp to POSIX path of (path to home folder) & {"Desktop", "Documents", "Downloads"}'s item (my indexOf(item 1 of ph))
						set okToLook to askAccess(fp)
					end if
					if okToLook then sh("bigfiles " & item 1 of ph)
				end repeat
				set f to sh("bigfiles finish")
				set lastAns to askDlg("Done. Your list is saved in Documents as Big files on this Mac. Press OK and it'll open in TextEdit, and I'll close so you can read it in peace.", {"OK"}, "OK")
				do shell script "open -a TextEdit " & quoted form of f
				exit repeat
			end if

		on error m number n
			if n is not -128 then error m number n
		end try
	end repeat
	closeStatus()
end mainRun
