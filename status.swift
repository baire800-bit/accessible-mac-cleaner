// A small, VoiceOver-friendly "working" window shared by Barry's apps.
// status <status-file> <title>
// Shows the text of <status-file> in a read-only field you reach with Tab, plus a Stop button.
// Every time the text changes it is announced. Writing "##CLOSE" to the file closes the window.
// Pressing Stop creates <status-file>.stop, which the calling app watches for.
import AppKit

final class ReadOnlyField: NSTextField {
    var onDown: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override func keyDown(with e: NSEvent) {
        if e.keyCode == 125, let f = onDown { f() } else { super.keyDown(with: e) }   // Down Arrow goes to the choices
    }
}
final class FocusButton: NSButton {
    var onArrow: ((FocusButton, Int) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 125, 124: if let f = onArrow { f(self, 1) } else { super.keyDown(with: e) }    // Down / Right: next button
        case 126, 123: if let f = onArrow { f(self, -1) } else { super.keyDown(with: e) }   // Up / Left: previous
        default: super.keyDown(with: e)
        }
    }
}

final class StatusApp: NSObject, NSApplicationDelegate {
    let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/status.txt"
    let title = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Working"
    var window: NSWindow!
    let field = ReadOnlyField(wrappingLabelWithString: "Starting.")
    var last = ""
    func applicationDidFinishLaunching(_ n: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 170),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.title = title
        field.isSelectable = true; field.isEditable = false
        field.setAccessibilityLabel("Status")
        let stop = FocusButton(title: "Stop", target: self, action: #selector(stopIt))
        let stack = NSStackView(views: [field, stop])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 484).isActive = true
        window.contentView = stack
        field.nextKeyView = stop; stop.nextKeyView = field
        window.center(); window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
        NSApp.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
    }
    func poll() {
        guard let t = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if s == "##CLOSE" { NSApp.terminate(nil); return }
        guard !s.isEmpty, s != last else { return }
        last = s; field.stringValue = s
        // Never pull focus back once you've gone elsewhere; if you're here, it's read to you.
        if NSApp.isActive {
            if window.firstResponder !== field { window.makeFirstResponder(field) }
            else { NSAccessibility.post(element: window as Any, notification: .announcementRequested,
                                        userInfo: [.announcement: s, .priority: NSAccessibilityPriorityLevel.high.rawValue]) }
        }
    }
    @objc func stopIt() {
        FileManager.default.createFile(atPath: path + ".stop", contents: Data())
        NSApp.terminate(nil)
    }
}
// Ask mode: status --ask <answer-file> <title> <message> <default button> <button> [<button>...]
// The message is a read-only field Tab reaches (focus starts on it), then the buttons in order.
// Return presses the default button; Escape presses Cancel or Skip if there is one.
// The pressed button's title is written to <answer-file>.
final class AskApp: NSObject, NSApplicationDelegate {
    let a = Array(CommandLine.arguments.dropFirst(2))
    var window: NSWindow!
    func applicationDidFinishLaunching(_ n: Notification) {
        let answerFile = a[0], title = a[1], message = a[2], def = a[3], titles = Array(a.dropFirst(4))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = title
        let field = ReadOnlyField(wrappingLabelWithString: message)
        field.isSelectable = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 524).isActive = true
        var buttons: [FocusButton] = []
        for t in titles {
            let b = FocusButton(title: t, target: nil, action: nil)
            b.target = self; b.action = #selector(pressed(_:))
            if t == def { b.keyEquivalent = "\r" }
            if t == "Cancel" || t == "Skip" || t == "Skip this folder" || t == "Skip those" { if t != def { b.keyEquivalent = "\u{1b}" } }
            buttons.append(b)
        }
        let row = NSStackView(views: buttons); row.spacing = 12
        let stack = NSStackView(views: [field, row])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        window.contentView = stack
        var prev: NSView = field
        for b in buttons { prev.nextKeyView = b; prev = b }
        prev.nextKeyView = field
        window.center(); window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
        NSApp.activate(ignoringOtherApps: true)
        _ = answerFile
    }
    @objc func pressed(_ b: NSButton) {
        try? b.title.write(toFile: a[0], atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
}

// Session mode: status --session <command-file> <app title>
// One window for a whole run, so focus never drops back to Finder between steps.
// The calling app writes ONE command at a time to <command-file>:
//   STATUS<tab>text                         show text in the read-only status field and announce it
//   ASK<tab>id<tab>default<tab>message<tab>button<tab>button...   show the message and buttons in the same window;
//                                           the pressed button is written to <command-file>.answer.<id>
//   CLOSE                                   quit
// Stop (while working) writes <command-file>.stop.
// A menu choice: Up and Down Arrow move between choices, Return picks.
final class MenuRadio: NSButton {
    var onMove: ((MenuRadio, Int) -> Void)?
    var onEnter: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 125, 124: onMove?(self, 1)
        case 126, 123: onMove?(self, -1)
        case 36, 76: onEnter?()
        default: super.keyDown(with: e)
        }
    }
}

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class SessionApp: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    let path = CommandLine.arguments[2]
    let appTitle = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "Working"
    var window: NSWindow!
    let field = ReadOnlyField(wrappingLabelWithString: "")
    let row = NSStackView()
    var last = ""
    var askID = ""
    var menuChoice = ""
    var radios: [MenuRadio] = []
    var job: Process?
    var ticking = false
    var tickTimer: Timer?
    func applicationDidFinishLaunching(_ n: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = appTitle
        let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item); let sub = NSMenu(); item.submenu = sub
        sub.addItem(withTitle: "Quit \(appTitle)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem); let em = NSMenu(title: "Edit"); editItem.submenu = em
        em.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        em.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        em.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        em.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = menu
        field.isSelectable = true
        field.font = .systemFont(ofSize: 15)
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 524).isActive = true
        row.spacing = 12
        let stack = NSStackView(views: [field, row])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        window.contentView = stack
        setButtons(["Stop"], def: "")
        window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(field)
        NSApp.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in self?.poll() }
        // A soft tick every few seconds while work is going on, so you know it hasn't stalled.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self, self.ticking else { return }
            let s = NSSound(named: "Morse"); s?.volume = 1.0; s?.play()
        }
    }
    // When the message has focus, the keys go to its text editor rather than the field itself,
    // so Down Arrow is caught here and sent to the first choice.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if (sel == #selector(NSResponder.moveDown(_:)) || sel == #selector(NSResponder.moveToEndOfDocument(_:))), let go = field.onDown { go(); return true }
        return false
    }
    func clearRadios() {
        for r in radios { r.removeFromSuperview() }; radios = []; checkKeys = []; field.onDown = nil
        listHolder?.removeFromSuperview(); listHolder = nil; inputBox = nil
    }
    var checkKeys: [String] = []
    var listHolder: NSView?
    var inputBox: NSTextField?
    var shownOnce = false
    func showInput(defaultText: String) {
        guard let stack = window.contentView as? NSStackView else { return }
        let t = NSTextField(string: defaultText); t.setAccessibilityLabel("Link")
        t.placeholderString = "Paste a link here, with Command-V"
        t.translatesAutoresizingMaskIntoConstraints = false
        t.widthAnchor.constraint(equalToConstant: 524).isActive = true
        stack.insertArrangedSubview(t, at: 1); inputBox = t; listHolder = t
    }
    func showChecklist(_ items: [String]) {   // each item: key|label|1 or 0
        clearRadios()
        guard let stack = window.contentView as? NSStackView else { return }
        let col = NSStackView(); col.orientation = .vertical; col.alignment = .leading; col.spacing = 6
        for it in items {
            let f = it.components(separatedBy: "|"); guard f.count >= 3 else { continue }
            let b = MenuRadio(checkboxWithTitle: f[1], target: nil, action: nil)
            b.state = f[2] == "1" ? .on : .off
            b.onMove = { [weak self] me, step in
                guard let self = self, let k = self.radios.firstIndex(of: me) else { return }
                if k + step < 0 { self.window.makeFirstResponder(self.field); return }
                let j = max(0, min(self.radios.count - 1, k + step))
                self.window.makeFirstResponder(self.radios[j])
                self.radios[j].scrollToVisible(self.radios[j].bounds.insetBy(dx: 0, dy: -20)) }
            b.onEnter = { [weak self] in if let ok = self?.row.arrangedSubviews.first as? NSButton { ok.performClick(nil) } }
            col.addArrangedSubview(b); radios.append(b); checkKeys.append(f[1] == "" ? f[0] : f[0])
        }
        // A long list (like your apps) scrolls inside the window instead of making it huge
        if radios.count > 8 {
            let doc = FlippedView(); doc.translatesAutoresizingMaskIntoConstraints = false
            col.translatesAutoresizingMaskIntoConstraints = false
            doc.addSubview(col)
            let sc = NSScrollView(); sc.documentView = doc; sc.hasVerticalScroller = true
            sc.setAccessibilityLabel("List")
            sc.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                col.topAnchor.constraint(equalTo: doc.topAnchor), col.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
                col.trailingAnchor.constraint(equalTo: doc.trailingAnchor), col.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
                doc.widthAnchor.constraint(equalTo: sc.contentView.widthAnchor),
                sc.heightAnchor.constraint(equalToConstant: 340), sc.widthAnchor.constraint(equalToConstant: 600)])
            stack.insertArrangedSubview(sc, at: 1); listHolder = sc
        } else {
            stack.insertArrangedSubview(col, at: 1); listHolder = col
        }
    }
    /// macOS only lets an app take the front if it asks while the app you launched is handing over, so ask
    /// firmly a few times in the first couple of seconds (only ever when the window first opens).
    func comeForward() {
        for delay in [0.0, 0.25, 0.6, 1.0, 1.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, !NSApp.isActive else { return }
                NSRunningApplication.current.activate(options: [.activateAllWindows])
                NSApp.activate(ignoringOtherApps: true)
                self.window.makeKeyAndOrderFront(nil)
                self.window.makeFirstResponder(self.field)
            }
        }
    }
    func setButtons(_ titles: [String], def: String) {
        for v in row.arrangedSubviews { row.removeArrangedSubview(v); v.removeFromSuperview() }
        var prev: NSView = radios.last ?? field
        if let firstRadio = radios.first { field.nextKeyView = firstRadio }
        for t in titles {
            let b = FocusButton(title: t, target: self, action: #selector(pressed(_:)))
            if t == def { b.keyEquivalent = "\r" }
            else if ["Cancel", "Close", "Skip", "Skip this folder", "Skip those", "Stop"].contains(t) { b.keyEquivalent = "\u{1b}" }
            row.addArrangedSubview(b); prev.nextKeyView = b; prev = b
            b.onArrow = { [weak self] me, step in
                guard let self = self else { return }
                let bs = self.row.arrangedSubviews.compactMap { $0 as? FocusButton }
                guard let i = bs.firstIndex(of: me) else { return }
                let j = i + step
                if j < 0 { self.window.makeFirstResponder(self.radios.last ?? self.field); return }
                if j >= bs.count { NSSound.beep(); return }
                self.window.makeFirstResponder(bs[j])
            }
        }
        prev.nextKeyView = field
    }
    func showMenu(_ options: [String]) {
        clearRadios()
        guard let stack = window.contentView as? NSStackView else { return }
        for (i, o) in options.enumerated() {
            let r = MenuRadio(radioButtonWithTitle: o, target: self, action: #selector(radioPicked(_:)))
            r.state = i == 0 ? .on : .off
            r.onMove = { [weak self] me, step in self?.moveRadio(from: me, by: step) }
            r.onEnter = { [weak self] in self?.chooseMenu() }
            stack.insertArrangedSubview(r, at: 1 + i)
            radios.append(r)
        }
        menuChoice = options.first ?? ""
        for (i, r) in radios.enumerated() { r.setAccessibilityLabel("\(r.title), \(i + 1) of \(radios.count)") }
    }
    func moveRadio(from r: MenuRadio, by step: Int) {
        guard let i = radios.firstIndex(of: r) else { return }
        if i + step < 0 { window.makeFirstResponder(field); return }
        let j = max(0, min(radios.count - 1, i + step))
        for (k, x) in radios.enumerated() { x.state = k == j ? .on : .off }
        menuChoice = radios[j].title; window.makeFirstResponder(radios[j])
    }
    @objc func radioPicked(_ r: NSButton) { for x in radios { x.state = x === r ? .on : .off }; menuChoice = r.title }
    /// After you answer: move focus to the message first, then swap in a short working note and remove the
    /// old controls, so VoiceOver doesn't re-read the screen you just left.
    func answered() {
        window.makeFirstResponder(field)
        field.stringValue = "Working on it."
        setButtons([], def: "")
        clearRadios()
        ticking = true
    }
    func chooseMenu() {
        guard !askID.isEmpty else { return }
        try? menuChoice.write(toFile: path + ".answer." + askID, atomically: true, encoding: .utf8)
        askID = ""; answered()
    }
    func run(_ id: String, _ args: [String]) {
        // Run the engine from this window's app, so any macOS permission alert belongs to the app in front.
        // The engine is clean.sh, unless the first word names another script in the same folder (Video Reader's read.sh)
        let res = Bundle.main.bundleURL.deletingLastPathComponent()
        var a = args
        let script = (a.first ?? "").hasSuffix(".sh") ? a.removeFirst() : "clean.sh"
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash"); p.arguments = [res.appendingPathComponent(script).path] + a
        // A script can report progress by writing a line to $STATUS; show each new line here
        let progress = path + ".progress." + id
        var env = ProcessInfo.processInfo.environment; env["STATUS"] = progress; p.environment = env
        var lastProgress = ""
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if let line = try? String(contentsOfFile: progress, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               !line.isEmpty, line != lastProgress, line != "Done." {
                lastProgress = line; self.ticking = true; self.setButtons(["Stop"], def: ""); self.show(line)
            }
            if !p.isRunning { t.invalidate(); try? FileManager.default.removeItem(atPath: progress) }
        }
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
        let out = path + ".answer." + id
        p.terminationHandler = { proc in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = "\(proc.terminationStatus)\n" + (String(data: data, encoding: .utf8) ?? "")
            try? text.write(toFile: out, atomically: true, encoding: .utf8)
        }
        job = p
        try? p.run()
        // A permission check that hasn't come back after a few seconds means macOS is showing its own alert.
        // Say so, and offer to jump to it, rather than leave you guessing.
        if args.first == "access", args.count > 1 {
            let folder = (args[1] as NSString).lastPathComponent
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, p.isRunning else { return }
                self.waitingFor = p
                self.ticking = false
                self.setButtons(["Show the alert", "Skip this folder"], def: "Show the alert")
                self.show("macOS wants to check it's OK for me to look in your \(folder) folder. VoiceOver doesn't always read macOS's alert, so press Show the alert to jump straight to it, then Tab to Allow and press Space. I'll carry on the moment you answer.")
                self.watchAccess(p)
            }
        }
    }
    var waitingFor: Process?
    func watchAccess(_ p: Process) {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if !p.isRunning { t.invalidate(); self.waitingFor = nil; self.setButtons(["Stop"], def: ""); self.ticking = true
                self.show("Thanks, that's sorted. Carrying on.") }
        }
    }
    func showAlert() {
        for id in ["com.apple.UserNotificationCenter", "com.apple.tccd"] {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) { app.activate() }
        }
    }
    func show(_ text: String) {
        if field.stringValue == text && window.firstResponder === field { return }
        field.stringValue = text
        // Come forward only when the window first opens. After that, never pull you back from another app;
        // the message waits here for you, and the calling app chimes or speaks when something needs you.
        if !shownOnce { shownOnce = true; window.makeKeyAndOrderFront(nil); comeForward() }
        guard NSApp.isActive else { return }
        // Put focus on the message so VoiceOver reads all of it, once. If focus was already there,
        // step off and back on so the new text is read from its first word (an announcement got cut short).
        if window.firstResponder === field {
            window.makeFirstResponder(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self = self else { return }
                self.window.makeFirstResponder(self.field)
            }
        } else {
            window.makeFirstResponder(field)
        }
    }
    var done = 0
    func poll() {
        // Commands arrive one per line and are handled in order, so none is missed.
        guard let t = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let lines = t.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        while done < lines.count {
            let line = lines[done].replacingOccurrences(of: "\\n", with: "\n")
            done += 1
            handle(line)
        }
    }
    func handle(_ t: String) {
        let parts = t.trimmingCharacters(in: .newlines).components(separatedBy: "\t")
        switch parts[0] {
        case "CLOSE": NSApp.terminate(nil)
        case "STATUS": askID = ""; ticking = true; clearRadios(); setButtons(["Stop"], def: ""); show(parts.count > 1 ? parts[1] : "")
        case "ASK" where parts.count >= 5:
            ticking = false; clearRadios()
            askID = parts[1]; setButtons(Array(parts.dropFirst(4)), def: parts[2]); show(parts[3])
            // Down Arrow from the message goes to the first button, as it goes to the choices elsewhere
            let target = row.arrangedSubviews.compactMap { $0 as? FocusButton }.first { $0.title == parts[2] } ?? row.arrangedSubviews.first
            if let b = target { field.onDown = { [weak self] in self?.window.makeFirstResponder(b) } }
        case "MENU" where parts.count >= 4:   // MENU id prompt option option...
            ticking = false; askID = parts[1]
            showMenu(Array(parts.dropFirst(3))); setButtons(["OK", "Close"], def: "OK"); show(parts[2])
            if let first = row.arrangedSubviews.first { for r in radios { r.nextKeyView = first } }
            if let r = radios.first { field.nextKeyView = r; field.onDown = { [weak self] in self?.window.makeFirstResponder(r) } }
        case "CHECK" where parts.count >= 5:  // CHECK id prompt okLabel key|label|on ...
            ticking = false; askID = parts[1]
            showChecklist(Array(parts.dropFirst(4)))
            setButtons([parts[3], "Cancel"], def: parts[3]); show(parts[2])
            if let first = row.arrangedSubviews.first { for r in radios { r.nextKeyView = first } }
            if let r = radios.first { field.nextKeyView = r; field.onDown = { [weak self] in self?.window.makeFirstResponder(r) } }
        case "INPUT" where parts.count >= 5:  // INPUT id prompt default okLabel: a text box to type or paste into
            ticking = false; clearRadios(); askID = parts[1]
            showInput(defaultText: parts[3])
            setButtons([parts[4], "Cancel"], def: parts[4]); show(parts[2])
            if let i = inputBox { field.nextKeyView = i; i.nextKeyView = row.arrangedSubviews.first
                field.onDown = { [weak self] in self?.window.makeFirstResponder(i) } }
        case "CHAT" where parts.count >= 3:   // CHAT readCopy savedPath: open a chat window in this same app
            #if VIDEO_READER
            Chat.openFor(readCopy: parts[1], saved: parts[2])
            #endif
        case "RUN" where parts.count >= 3:    // RUN id arg arg...
            run(parts[1], Array(parts.dropFirst(2)))
        default: break
        }
    }
    @objc func pressed(_ b: NSButton) {
        if let w = waitingFor {
            if b.title == "Show the alert" { showAlert(); return }
            if b.title == "Skip this folder" { w.terminate(); waitingFor = nil; show("No problem, I'll leave that folder alone."); return }
        }
        if askID.isEmpty {   // Stop while working
            job?.terminate()
            FileManager.default.createFile(atPath: path + ".stop", contents: Data())
            ticking = false; field.stringValue = "Stopping."; return
        }
        if let i = inputBox, b.title != "Cancel" {
            try? i.stringValue.write(toFile: path + ".answer." + askID, atomically: true, encoding: .utf8)
            inputBox = nil; askID = ""; answered(); return
        }
        if inputBox != nil { inputBox = nil }
        if !checkKeys.isEmpty && b.title != "Cancel" {
            let ticked = zip(radios, checkKeys).filter { $0.0.state == .on }.map { $0.1 }.joined(separator: "\n")
            try? (ticked.isEmpty ? "NONE" : ticked).write(toFile: path + ".answer." + askID, atomically: true, encoding: .utf8)
            askID = ""; answered(); return
        }
        if !radios.isEmpty && b.title == "OK" { chooseMenu(); return }
        if !radios.isEmpty { clearRadios() }
        try? b.title.write(toFile: path + ".answer." + askID, atomically: true, encoding: .utf8)
        askID = ""; answered()
    }
}

@main struct Main {
    static func main() {
        let app = NSApplication.shared
        if CommandLine.arguments.count > 2 && CommandLine.arguments[1] == "--session" {
            let d = SessionApp(); app.delegate = d; app.setActivationPolicy(.regular); app.run(); return
        }
        if CommandLine.arguments.count > 1 && CommandLine.arguments[1] == "--ask" {
            let d = AskApp(); app.delegate = d; app.setActivationPolicy(.regular); app.run(); return
        }
        let d = StatusApp(); app.delegate = d
        app.setActivationPolicy(.regular); app.run()
    }
}
