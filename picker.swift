// Accessible Mac Cleaner: app picker with a checkbox for each app.
// Prints the paths of the ticked apps, one per line, then exits. Prints nothing if cancelled.
import AppKit

struct AppInfo: Identifiable {
    let id: String          // path
    let name: String
    let bytes: Int64
    let category: String
    let lastUsed: Date?
    var summary: String {
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        let used: String
        if let d = lastUsed {
            let f = DateFormatter(); f.dateFormat = "d MMMM yyyy"
            used = "Last used \(f.string(from: d))"
        } else { used = "Never used, or not recorded" }
        return "\(name). \(size). \(category). \(used)."
    }
}

func meta(_ path: String, _ key: String) -> Any? {
    guard let item = MDItemCreate(nil, path as CFString) else { return nil }
    return MDItemCopyAttribute(item, key as CFString)
}

func protected(_ path: String) -> Bool {
    var st = stat()
    guard lstat(path, &st) == 0 else { return true }
    if (st.st_flags & UInt32(SF_RESTRICTED)) != 0 { return true }   // system-protected, e.g. Safari
    return (st.st_mode & S_IFMT) == S_IFLNK
}

func loadApps() -> [AppInfo] {
    let dir = "/Applications"
    let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
    var out: [AppInfo] = []
    for n in names where n.hasSuffix(".app") {
        let p = dir + "/" + n
        if protected(p) { continue }
        if p.hasSuffix("Accessible Mac Cleaner.app") { continue }
        let bytes = (meta(p, "kMDItemPhysicalSize") as? NSNumber)?.int64Value ?? 0
        var cat = (meta(p, "kMDItemAppStoreCategory") as? String) ?? ""
        if cat.isEmpty, let info = NSDictionary(contentsOfFile: p + "/Contents/Info.plist"),
           let c = info["LSApplicationCategoryType"] as? String {
            cat = c.replacingOccurrences(of: "public.app-category.", with: "")
                   .replacingOccurrences(of: "-", with: " ").capitalized
        }
        let category = cat.isEmpty ? "No category given" : "\(cat) app"
        out.append(AppInfo(id: p, name: String(n.dropLast(4)), bytes: bytes, category: category,
                           lastUsed: meta(p, "kMDItemLastUsedDate") as? Date))
    }
    return out
}


enum SortOrder: Int { case name = 0, size, used }

// One real checkbox per app. Up and Down Arrow move between them, Space ticks, so VoiceOver
// just follows focus: no table to interact with and no VO-Space needed.
final class TickBox: NSButton {
    var onMove: ((TickBox, Int) -> Void)?
    var onTab: ((TickBox, Bool) -> Void)?
    var onChange: ((TickBox) -> Void)?
    var appID = ""
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { scrollToVisible(bounds.insetBy(dx: 0, dy: -30)) }
        return ok
    }
    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 125: onMove?(self, 1)      // down arrow
        case 126: onMove?(self, -1)     // up arrow
        case 115: onMove?(self, -10000) // home
        case 119: onMove?(self, 10000)  // end
        case 49:  performClick(nil)     // space
        case 48:  onTab?(self, e.modifierFlags.contains(.shift))  // tab leaves the list
        default: super.keyDown(with: e)
        }
    }
}
// Buttons that Tab can always reach, even without Full Keyboard Access switched on.
final class FocusButton: NSButton { override var canBecomeKeyView: Bool { isEnabled }; override var acceptsFirstResponder: Bool { isEnabled } }
final class FocusPopUp: NSPopUpButton { override var canBecomeKeyView: Bool { true }; override var acceptsFirstResponder: Bool { true } }
final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class Controller: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let listStack = NSStackView()
    var boxes: [TickBox] = []
    let sortMenu = FocusPopUp()
    let status = NSTextField(labelWithString: "")
    let goButton = FocusButton(title: "Uninstall ticked apps", target: nil, action: nil)
    var lastBox: TickBox?
    var apps = loadApps()
    var shown: [AppInfo] = []
    var ticked = Set<String>()

    func applicationDidFinishLaunching(_ n: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Uninstall apps"
        let intro = NSTextField(wrappingLabelWithString: "Tick the apps you want to uninstall. Up and Down Arrow move through the apps, Space ticks or unticks one, Home and End jump to the first and last. Command-A ticks all, Command-D unticks all. Nothing is removed until you confirm on the next screen, and everything goes to the Bin.")
        let sortLabel = NSTextField(labelWithString: "Sort by:")
        sortMenu.addItems(withTitles: ["Name", "Size, biggest first", "Last used, oldest first"])
        sortMenu.target = self; sortMenu.action = #selector(resort)
        sortMenu.setAccessibilityLabel("Sort by")
        listStack.orientation = .vertical; listStack.alignment = .leading; listStack.spacing = 4
        listStack.translatesAutoresizingMaskIntoConstraints = false
        let doc = FlippedView(); doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(listStack)
        let scroll = NSScrollView(); scroll.documentView = doc; scroll.hasVerticalScroller = true
        scroll.setAccessibilityLabel("Apps")
        NSLayoutConstraint.activate([
            listStack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 4),
            listStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 4),
            listStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -4),
            listStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -4),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)])
        let cancel = FocusButton(title: "Cancel", target: self, action: #selector(cancelIt)); cancel.keyEquivalent = "\u{1b}"
        goButton.target = self; goButton.action = #selector(finish)
        let sortRow = NSStackView(views: [sortLabel, sortMenu])
        let buttons = NSStackView(views: [cancel, NSView(), goButton])
        let stack = NSStackView(views: [intro, sortRow, scroll, status, buttons])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        for v in [scroll, buttons, intro] { v.translatesAutoresizingMaskIntoConstraints = false }
        window.contentView = stack
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            intro.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 380)])
        let menu = NSMenu(); let appItem = NSMenuItem(); menu.addItem(appItem)
        let sub = NSMenu(); appItem.submenu = sub
        sub.addItem(withTitle: "Tick all", action: #selector(tickAll), keyEquivalent: "a").target = self
        sub.addItem(withTitle: "Untick all", action: #selector(untickAll), keyEquivalent: "d").target = self
        sub.addItem(withTitle: "Quit", action: #selector(cancelIt), keyEquivalent: "q").target = self
        NSApp.mainMenu = menu
        resort(); refreshStatus()
        sortMenu.nextKeyView = boxes.first
        goButton.nextKeyView = cancel
        cancel.nextKeyView = sortMenu
        window.center(); window.makeKeyAndOrderFront(nil)
        if let first = boxes.first { window.initialFirstResponder = first; window.makeFirstResponder(first) }
        NSApp.activate(ignoringOtherApps: true)
    }
    func rebuild() {
        for b in boxes { listStack.removeArrangedSubview(b); b.removeFromSuperview() }
        boxes = shown.map { a in
            let b = TickBox(checkboxWithTitle: a.summary, target: self, action: #selector(clicked(_:)))
            b.appID = a.id; b.state = ticked.contains(a.id) ? .on : .off
            b.onMove = { [weak self] box, step in self?.move(from: box, by: step) }
            b.onTab = { [weak self] box, back in self?.leaveList(from: box, backwards: back) }
            listStack.addArrangedSubview(b)
            return b
        }
        for b in boxes { b.nextKeyView = goButton }
    }
    func leaveList(from box: TickBox, backwards: Bool) {
        lastBox = box
        sortMenu.nextKeyView = box          // Tab from Sort by comes back to the app you were on
        if backwards { window.makeFirstResponder(sortMenu) }
        else { window.makeFirstResponder(goButton.isEnabled ? goButton : goButton.nextKeyView) }
    }
    func move(from box: TickBox, by step: Int) {
        guard let i = boxes.firstIndex(of: box) else { return }
        let j = max(0, min(boxes.count - 1, i + step))
        if j != i { window.makeFirstResponder(boxes[j]) } else { NSSound.beep() }
    }
    @objc func clicked(_ b: NSButton) {
        guard let t = b as? TickBox else { return }
        if t.state == .on { ticked.insert(t.appID) } else { ticked.remove(t.appID) }
        refreshStatus()
    }
    func announce(_ s: String) {
        NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested,
                             userInfo: [.announcement: s, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
    func refreshStatus() {
        let b = apps.filter { ticked.contains($0.id) }.reduce(Int64(0)) { $0 + $1.bytes }
        status.stringValue = ticked.isEmpty ? "Nothing ticked yet." : "\(ticked.count) ticked, \(ByteCountFormatter.string(fromByteCount: b, countStyle: .file)) in total."
        goButton.isEnabled = !ticked.isEmpty
    }
    @objc func resort() {
        switch SortOrder(rawValue: sortMenu.indexOfSelectedItem) ?? .name {
        case .name: shown = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size: shown = apps.sorted { $0.bytes > $1.bytes }
        case .used: shown = apps.sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
        }
        rebuild()
        sortMenu.nextKeyView = boxes.first
        if window != nil, let first = boxes.first { window.makeFirstResponder(first) }
    }
    @objc func tickAll() { for a in apps { ticked.insert(a.id) }; for b in boxes { b.state = .on }; refreshStatus(); announce("All \(apps.count) apps ticked.") }
    @objc func untickAll() { ticked.removeAll(); for b in boxes { b.state = .off }; refreshStatus(); announce("All apps unticked.") }
    @objc func cancelIt() { NSApp.terminate(nil) }
    @objc func finish() {
        for a in shown where ticked.contains(a.id) { print(a.id) }
        fflush(stdout); NSApp.terminate(nil)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) { print("##END"); fflush(stdout) }
}

@main struct Main {
    static func main() {
        if let i = CommandLine.arguments.firstIndex(of: "--items") {   // path|summary|0 lines for the one-window list
            let order = CommandLine.arguments.count > i + 1 ? CommandLine.arguments[i + 1] : "name"
            var a = loadApps()
            switch order {
            case "size": a.sort { $0.bytes > $1.bytes }
            case "used": a.sort { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
            default: a.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            for x in a { print("\(x.id)|\(x.summary.replacingOccurrences(of: "|", with: "/"))|0") }
            return
        }
        if CommandLine.arguments.contains("--list") {
            for a in loadApps().sorted(by: { $0.bytes > $1.bytes }) { print(a.summary) }
            return
        }
        let app = NSApplication.shared
        let c = Controller(); app.delegate = c
        app.setActivationPolicy(.regular)
        app.run()
    }
}
