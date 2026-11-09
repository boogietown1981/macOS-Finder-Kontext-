import AppKit
import ApplicationServices
import FinderSync
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem?
    var setupWindow: NSWindow?
    var accessLabel = NSTextField(labelWithString: "")
    var automationLabel = NSTextField(labelWithString: "")
    var extensionLabel = NSTextField(labelWithString: "")
    var progressLabel = NSTextField(wrappingLabelWithString: "Bereit. Wähle Dateien im Finder aus.")
    var timer: Timer?
    var busy = false
    let marker = NSPasteboard.PasteboardType("de.itso.FinderExtras.operation")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status?.button?.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "FinderExtras")
        status?.button?.image?.isTemplate = true
        status?.button?.toolTip = "FinderExtras"
        let menu = NSMenu()
        for (title, action) in [
            ("Ausschneiden", "cut"), ("Kopieren", "copy"), ("Einfügen", "paste"),
            ("Hierher verschieben", "move"), ("Als Kopie einfügen", "pasteCopy"),
            ("Pfade kopieren", "paths"), ("—", ""),
            ("Versteckte Dateien ein/aus", "hidden"), ("Pfadleiste ein/aus", "pathbar"),
            ("Vorschauseitenleiste ein/aus", "preview"), ("Auswahl in neuen Ordner", "group"),
            ("Unterordner aufklappen (Liste)", "expand"), ("Unterordner zuklappen (Liste)", "collapse"),
            ("Schnellvorschau", "quicklook"), ("Diashow", "slideshow"),
            ("Gehe zum Ordner …", "goto"), ("Mit Server verbinden …", "server"),
            ("Übergeordneten Ordner öffnen", "parent"), ("—", ""),
            ("Einrichtung & Status …", "setup"), ("Dienste neu registrieren", "register"), ("Beenden", "quit")
        ] {
            if action.isEmpty { menu.addItem(.separator()); continue }
            let item = NSMenuItem(title: title, action: #selector(clicked(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = action; menu.addItem(item)
        }
        status?.menu = menu
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshPermissions() }
        if UserDefaults.standard.string(forKey: "setupVersion") != "0.2" {
            UserDefaults.standard.set("0.2", forKey: "setupVersion")
            DispatchQueue.main.async { self.showSetup() }
        }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy { message("Bitte die laufende Übertragung abwarten."); return .terminateCancel }
        return .terminateNow
    }
    func message(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "FinderExtras"; alert.informativeText = text; alert.runModal()
    }
    func run(_ operation: () throws -> Void) {
        guard !busy else { message("Eine Übertragung läuft bereits."); return }
        do { try operation() } catch { message(error.localizedDescription) }
    }
    @objc func clicked(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? String else { return }
        DispatchQueue.main.async { self.run { try self.perform(action) } }
    }
    @discardableResult func script(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw TransferFailure(message: "AppleScript konnte nicht erstellt werden.") }
        let result = script.executeAndReturnError(&error)
        if let error = error { throw TransferFailure(message: "\(error)") }
        return result
    }
    func key(_ command: String) throws {
        guard AXIsProcessTrusted() else { showSetup(); throw TransferFailure(message: "Diese Ansichtsaktion benötigt Bedienungshilfen. Bitte im Einrichtungsfenster freigeben.") }
        try script("""
        tell application "Finder" to activate
        tell application "System Events"
            tell process "Finder"
                repeat 40 times
                    if frontmost then exit repeat
                    delay 0.05
                end repeat
                if not frontmost then error "Finder konnte nicht aktiviert werden."
                \(command)
            end tell
        end tell
        """)
    }
    func selectedFiles() throws -> [URL] {
        let result = try script("""
        tell application "Finder"
            set paths to {}
            repeat with f in (get selection)
                set end of paths to POSIX path of (f as alias)
            end repeat
            return paths
        end tell
        """)
        guard result.numberOfItems > 0 else { throw TransferFailure(message: "Bitte zuerst Dateien auswählen.") }
        return (1...result.numberOfItems).compactMap { index in
            guard let path = result.atIndex(index)?.stringValue else { return nil }
            return URL(fileURLWithPath: path)
        }
    }
    func currentFolder() throws -> URL {
        let result = try script("""
        tell application "Finder"
            if (count of Finder windows) is 0 then error "Bitte einen Zielordner im Finder öffnen."
            return POSIX path of (target of front Finder window as alias)
        end tell
        """)
        guard let path = result.stringValue else { throw TransferFailure(message: "Zielordner nicht ermittelbar.") }
        return URL(fileURLWithPath: path)
    }
    func files(_ board: NSPasteboard) -> [URL] {
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty { return urls }
        return (board.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] ?? []).filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0) }
    }
    func capture(_ urls: [URL], cut: Bool) throws {
        guard !urls.isEmpty else { throw TransferFailure(message: "Keine Dateien ausgewählt.") }
        let board = NSPasteboard.general; board.clearContents()
        guard board.writeObjects(urls.map { $0 as NSURL }) else { throw TransferFailure(message: "Zwischenablage konnte nicht beschrieben werden.") }
        board.setString(cut ? "move" : "copy", forType: marker)
        let text = "\(urls.count) Objekt(e) zum \(cut ? "Verschieben" : "Kopieren") vorgemerkt."
        progressLabel.stringValue = text; status?.button?.toolTip = "FinderExtras — " + text
    }
    func copyPaths(_ urls: [URL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urls.map { $0.path }.joined(separator: "\n"), forType: .string)
    }
    func transfer(mode: String, target: URL? = nil) throws {
        let board = NSPasteboard.general
        let sources = files(board)
        guard !sources.isEmpty else { throw TransferFailure(message: "Die Zwischenablage enthält keine Dateien. Bitte zuerst Dateien ausschneiden oder kopieren.") }
        let move = mode == "move" || (mode == "paste" && board.string(forType: marker) == "move")
        let destination: URL
        if let target = target { destination = target } else { destination = try currentFolder() }
        let plan = try TransferEngine().plan(sources, into: destination)
        // Also protects the URL entry point: no external URL can silently move files.
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "\(sources.count) Objekt(e) \(move ? "verschieben" : "kopieren")?"
        alert.informativeText = "Ziel: \(destination.path)\n\n" + (move ? "Nach erfolgreicher Übertragung sind die Dateien am bisherigen Ort nicht mehr vorhanden." : "Die Quelldateien bleiben erhalten.")
        alert.addButton(withTitle: move ? "Verschieben" : "Kopieren"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let count = board.changeCount
        busy = true; showSetup()
        progressLabel.stringValue = "Übertragung startet …"
        DispatchQueue.global(qos: .userInitiated).async {
            var failure: String?
            do {
                try TransferEngine().execute(plan, move: move) { index, name in
                    DispatchQueue.main.async { self.progressLabel.stringValue = "\(move ? "Verschiebe" : "Kopiere") \(index + 1)/\(plan.count): \(name)" }
                }
            } catch { failure = error.localizedDescription }
            let result = failure
            DispatchQueue.main.async {
                self.busy = false
                if move && NSPasteboard.general.changeCount == count { NSPasteboard.general.clearContents() }
                let summary = result ?? "\(plan.count) Objekt(e) \(move ? "verschoben; Quellen entfernt" : "kopiert; Quellen erhalten")."
                self.progressLabel.stringValue = summary
                self.status?.button?.toolTip = "FinderExtras — " + summary
                if let result = result { self.message(result) }
            }
        }
    }
    func perform(_ action: String) throws {
        switch action {
        case "cut", "copy": try capture(selectedFiles(), cut: action == "cut")
        case "paste", "move", "pasteCopy": try transfer(mode: action)
        case "paths": copyPaths(try selectedFiles())
        case "setup": showSetup()
        case "register": NSUpdateDynamicServices(); showSetup()
        case "quit": NSApp.terminate(nil)
        default:
            let keys = ["hidden":"keystroke \".\" using {command down, shift down}", "pathbar":"keystroke \"p\" using {command down, option down}", "preview":"keystroke \"p\" using {command down, shift down}", "group":"keystroke \"n\" using {command down, control down}", "expand":"key code 124 using {option down}", "collapse":"key code 123 using {option down}", "quicklook":"keystroke \"y\" using {command down}", "slideshow":"keystroke \"y\" using {command down, option down}", "goto":"keystroke \"g\" using {command down, shift down}", "server":"keystroke \"k\" using {command down}", "parent":"key code 126 using {command down}"]
            if let keyCommand = keys[action] { try key(keyCommand) }
        }
    }
    @objc func finderService(_ board: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = files(board); let action = userData ?? "paths"
        DispatchQueue.main.async {
            self.run {
                guard !urls.isEmpty else { throw TransferFailure(message: "Keine Dateien übergeben.") }
                if action == "cut" { try self.capture(urls, cut: true) }
                else if action == "paths" { self.copyPaths(urls) }
                else if action == "move", urls.count == 1 { try self.transfer(mode: "move", target: urls[0]) }
            }
        }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "finderextras", url.host == "action", url.absoluteString.count < 1000000,
                  let payload = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "payload" })?.value,
                  let data = Data(base64Encoded: payload),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let action = object["action"] as? String, ["cut","copy","paths","paste","move"].contains(action),
                  let paths = object["paths"] as? [String], paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") }) else { continue }
            let selection = paths.map { URL(fileURLWithPath: $0) }
            DispatchQueue.main.async {
                self.run {
                    if action == "cut" || action == "copy" { try self.capture(selection, cut: action == "cut") }
                    else if action == "paths" { self.copyPaths(selection) }
                    else if let target = object["target"] as? String, target.hasPrefix("/"), !target.contains("\0") {
                        try self.transfer(mode: action, target: URL(fileURLWithPath: target))
                    }
                }
            }
        }
    }

    func permission(_ bundle: String, prompt: Bool = false) -> OSStatus {
        guard let target = NSAppleEventDescriptor(descriptorType: typeApplicationBundleID, data: Data(bundle.utf8)) else { return OSStatus(-50) }
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, prompt)
    }
    func refreshPermissions() {
        guard setupWindow?.isVisible == true else { return }
        accessLabel.stringValue = AXIsProcessTrusted() ? "✓ Bedienungshilfen freigegeben" : "○ Bedienungshilfen noch nicht freigegeben"
        extensionLabel.stringValue = FIFinderSyncController.isExtensionEnabled ? "✓ Finder-Erweiterung aktiviert" : "○ Finder-Erweiterung noch nicht aktiviert"
        let finder = permission("com.apple.finder") == noErr
        let events = permission("com.apple.systemevents") == noErr
        automationLabel.stringValue = "Finder: \(finder ? "✓ erlaubt" : "○ offen")   ·   System Events: \(events ? "✓ erlaubt" : "○ offen")"
    }
    func showSetup() {
        if setupWindow == nil { buildSetup() }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil); refreshPermissions()
    }
    func buildSetup() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 670), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "FinderExtras · Einrichtung & Status"; window.isReleasedWhenClosed = false; window.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let document = NSView(); document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document; document.addSubview(stack)
        window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)])
        func text(_ value: String, bold: Bool = false) {
            let label = NSTextField(wrappingLabelWithString: value)
            label.font = bold ? .boldSystemFont(ofSize: 17) : .systemFont(ofSize: 12)
            stack.addArrangedSubview(label); label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        func button(_ title: String, selector: Selector) {
            let button = NSButton(title: title, target: self, action: selector); button.bezelStyle = .rounded; stack.addArrangedSubview(button)
        }
        text("FinderExtras 0.2.0", bold: true)
        text("Ausschneiden → Einfügen verschiebt. Kopieren → Einfügen kopiert. Vor jeder Übertragung zeigt die App das Ziel und die Aktion. Gleichnamige Zieldateien werden nicht ersetzt.")
        stack.addArrangedSubview(extensionLabel)
        text("1 · Für die Einträge direkt im Finder-Rechtsklickmenü die FinderExtras-Erweiterung aktivieren. macOS bestimmt die Reihenfolge. Dienste bleiben als Alternative verfügbar.")
        button("Finder-Erweiterung aktivieren …", selector: #selector(openExtensions))
        stack.addArrangedSubview(automationLabel)
        text("2 · Finder-Automation liest die Auswahl für das Menüleistensymbol. System Events steuert nur die zusätzlichen Ansichtsaktionen. Die direkten Kontext-Dateiaktionen benötigen beides nicht.")
        button("Automation anfragen …", selector: #selector(requestAutomation))
        stack.addArrangedSubview(accessLabel)
        text("3 · Bedienungshilfen erlauben die Ansichts-Kurzbefehle. Nach lokalen Updates kann eine erneute Freigabe nötig sein. Vollzugriff auf die Festplatte ist keine Standardanforderung.")
        button("Bedienungshilfen freigeben …", selector: #selector(requestAccessibility))
        button("Installierte App im Finder zeigen", selector: #selector(revealApp))
        text("Dateizugriff: macOS fragt geschützte Ordner bei Bedarf an. Freigaben lassen sich nicht stillschweigend einschalten. Für NAS müssen die Freigabe verbunden und Schreib-/Löschrechte vorhanden sein.")
        let separator = NSBox(); separator.boxType = .separator; stack.addArrangedSubview(separator); separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.addArrangedSubview(progressLabel); progressLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        setupWindow = window
    }
    @objc func openExtensions() { FIFinderSyncController.showExtensionManagementInterface() }
    @objc func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func requestAutomation() {
        _ = permission("com.apple.finder", prompt: true)
        _ = permission("com.apple.systemevents", prompt: true)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
        refreshPermissions()
    }
    @objc func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
