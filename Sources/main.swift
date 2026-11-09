import AppKit
import ApplicationServices

// All mutations are delegated to Finder. No file is deleted by this app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var busy = false
    let help = """
    FinderExtras 0.1.1 — lokale Testversion

    1. Dateien im Finder auswählen → Ausschneiden (vormerken).
    2. Zielordner öffnen → Hierher verschieben.
    Finder führt die Übertragung und seine Konfliktdialoge aus.
    Ausschneiden kopiert zunächst nur: Erst Hierher verschieben bewegt Dateien.
    Ein späteres Kopieren ersetzt die Zwischenablage. Keine ausgegrauten Dateien.

    Rechtsklick → Dienste: Ausschneiden, in gewählten Ordner verschieben,
    Pfade kopieren. Bei Bedarf unter Systemeinstellungen → Tastatur →
    Tastaturkurzbefehle → Dienste aktivieren. Ein leerer Fensterbereich bietet
    nicht immer Dienste; dafür das Menüleistensymbol verwenden.

    Erlaubnisse: Datenschutz & Sicherheit → Bedienungshilfen → FinderExtras.
    Zusätzlich Automation für Finder und System Events erlauben.
    Die App sendet nur nach deinem Klick Finder-Kurzbefehle; kein Tastaturmonitor.

    Optional: App zu Allgemein → Anmeldeobjekte hinzufügen.
    Beenden über dieses Menü. Deinstallation: App beenden und aus
    ~/Applications entfernen. Es werden keine Dateien oder Einstellungen
    deiner Ordner verändert, außer durch bewusst ausgelöste Finder-Aktionen.
    """
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "FinderExtras")
        status.button?.toolTip = "FinderExtras — Finder-Werkzeuge"
        let menu = NSMenu()
        add(menu, "Ausschneiden (vormerken)", "cut")
        add(menu, "Hierher verschieben", "move")
        add(menu, "Kopieren", "copy")
        add(menu, "Einfügen (Kopie)", "paste")
        add(menu, "Pfade der Auswahl kopieren", "paths")
        menu.addItem(.separator())
        add(menu, "Versteckte Dateien ein/aus", "hidden")
        add(menu, "Pfadleiste ein/aus", "pathbar")
        add(menu, "Vorschauseitenleiste ein/aus", "preview")
        add(menu, "Auswahl in neuen Ordner", "group")
        add(menu, "Unterordner aufklappen (Listenansicht)", "expand")
        add(menu, "Unterordner zuklappen (Listenansicht)", "collapse")
        add(menu, "Schnellvorschau", "quicklook")
        add(menu, "Diashow der Auswahl", "slideshow")
        menu.addItem(.separator())
        add(menu, "Gehe zum Ordner …", "goto")
        add(menu, "Mit NAS / Server verbinden …", "server")
        add(menu, "Übergeordneten Ordner öffnen", "parent")
        menu.addItem(.separator())
        add(menu, "Dienste neu registrieren", "register")
        add(menu, "Hilfe und Einrichtung …", "help")
        add(menu, "Beenden", "quit")
        status.menu = menu
        if !UserDefaults.standard.bool(forKey: "shownWelcome") {
            UserDefaults.standard.set(true, forKey: "shownWelcome")
            DispatchQueue.main.async { self.message(self.help) }
        }
    }
    func add(_ menu: NSMenu, _ title: String, _ action: String) {
        let item = NSMenuItem(title: title, action: #selector(clicked(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = action
        menu.addItem(item)
    }
    func message(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "FinderExtras"
        alert.informativeText = text
        alert.runModal()
    }
    @discardableResult func script(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw NSError(domain: "FinderExtras", code: 1, userInfo: [NSLocalizedDescriptionKey: "AppleScript konnte nicht erstellt werden."])
        }
        let result = script.executeAndReturnError(&error)
        if let error = error {
            throw NSError(domain: "FinderExtras", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
        }
        return result
    }
    // Escaping prevents filenames from becoming executable AppleScript.
    func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
    func key(_ command: String) throws {
        guard AXIsProcessTrusted() else {
            throw NSError(domain: "FinderExtras", code: 3, userInfo: [NSLocalizedDescriptionKey: "Bitte FinderExtras unter Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen erlauben und erneut versuchen."])
        }
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
    func run(_ operation: () throws -> Void) {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do { try operation() } catch { message(error.localizedDescription) }
    }
    @objc func clicked(_ item: NSMenuItem) {
        guard let action = item.representedObject as? String else { return }
        // Let the status menu close before sending input to Finder.
        DispatchQueue.main.async { self.run { try self.perform(action) } }
    }
    func perform(_ action: String) throws {
        switch action {
        case "register":
            NSUpdateDynamicServices()
            message("Dienste wurden zur erneuten Registrierung gemeldet. Bitte im Finder eine Datei auswählen und unter Finder → Dienste prüfen. Falls weiterhin nichts erscheint, einmal ab- und wieder anmelden.")
        case "help": message(help)
        case "quit": NSApp.terminate(nil)
        case "paths":
            let result = try script("""
            tell application "Finder"
                set paths to {}
                repeat with f in (get selection)
                    set end of paths to POSIX path of (f as alias)
                end repeat
                return paths
            end tell
            """)
            let paths = (1...max(1, result.numberOfItems)).compactMap { result.atIndex($0)?.stringValue }
            guard !paths.isEmpty else { throw noSelection() }
            copyPaths(paths)
        default:
            if action == "move" || action == "paste" {
                guard !files(NSPasteboard.general).isEmpty else {
                    throw NSError(domain: "FinderExtras", code: 6, userInfo: [NSLocalizedDescriptionKey: "Die Zwischenablage enthält keine Dateien. Bitte zuerst Dateien im Finder kopieren oder Ausschneiden (vormerken) verwenden."])
                }
            }
            if action == "cut" || action == "copy" || action == "group" {
                try script("""
                tell application "Finder"
                    set chosen to selection
                    if (count of chosen) is 0 then error "Bitte zuerst Dateien im Finder auswählen."
                    select chosen
                end tell
                """)
            }
            let commands: [String: String] = [
                "cut": "keystroke \"c\" using {command down}",
                "copy": "keystroke \"c\" using {command down}",
                "move": "keystroke \"v\" using {command down, option down}",
                "paste": "keystroke \"v\" using {command down}",
                "hidden": "keystroke \".\" using {command down, shift down}",
                "pathbar": "keystroke \"p\" using {command down, option down}",
                "preview": "keystroke \"p\" using {command down, shift down}",
                "group": "keystroke \"n\" using {command down, control down}",
                "expand": "key code 124 using {option down}",
                "collapse": "key code 123 using {option down}",
                "quicklook": "keystroke \"y\" using {command down}",
                "slideshow": "keystroke \"y\" using {command down, option down}",
                "goto": "keystroke \"g\" using {command down, shift down}",
                "server": "keystroke \"k\" using {command down}",
                "parent": "key code 126 using {command down}"
            ]
            if let command = commands[action] { try key(command) }
        }
    }
    func noSelection() -> NSError {
        NSError(domain: "FinderExtras", code: 4, userInfo: [NSLocalizedDescriptionKey: "Bitte Dateien oder einen Zielordner im Finder auswählen."])
    }
    func copyPaths(_ paths: [String]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }
    func files(_ board: NSPasteboard) -> [URL] {
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty { return urls }
        let legacy = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        return (board.propertyList(forType: legacy) as? [String] ?? []).map { URL(fileURLWithPath: $0) }
    }
    @objc func finderService(_ board: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = files(board)
        let action = userData ?? "paths"
        // Services must return promptly; the pasteboard is captured before returning.
        DispatchQueue.main.async {
            self.run {
                guard !urls.isEmpty else { throw self.noSelection() }
                if action == "paths" { self.copyPaths(urls.map { $0.path }); return }
                if action == "cut" {
                    let aliases = urls.map { "(POSIX file \(self.literal($0.path)) as alias)" }.joined(separator: ", ")
                    try self.script("tell application \"Finder\" to select {\(aliases)}")
                    try self.perform("cut")
                } else if action == "move" {
                    guard urls.count == 1,
                          (try urls[0].resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else {
                        throw NSError(domain: "FinderExtras", code: 5, userInfo: [NSLocalizedDescriptionKey: "Bitte genau einen Zielordner auswählen."])
                    }
                    try self.script("""
                    tell application "Finder"
                        activate
                        make new Finder window to (POSIX file \(self.literal(urls[0].path)) as alias)
                    end tell
                    """)
                    try self.perform("move")
                }
            }
        }
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
