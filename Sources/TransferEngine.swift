import Foundation

struct TransferFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
struct TransferEngine {
    let fm = FileManager.default
    func exists(_ url: URL) -> Bool { (try? fm.attributesOfItem(atPath: url.path)) != nil }
    func plan(_ sources: [URL], into destination: URL) throws -> [(URL, URL)] {
        guard !sources.isEmpty else { throw TransferFailure(message: "Keine Dateien ausgewählt.") }
        let destination = destination.standardizedFileURL.resolvingSymlinksInPath()
        guard (try destination.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else {
            throw TransferFailure(message: "Das Ziel ist kein Ordner.")
        }
        var names = Set<String>()
        let canonical = sources.map { $0.standardizedFileURL }
        for source in canonical {
            guard exists(source) else { throw TransferFailure(message: "Quelle nicht erreichbar: \(source.path)") }
            guard source.path != "/", names.insert(source.lastPathComponent.lowercased()).inserted else {
                throw TransferFailure(message: "Mehrere Quellen haben denselben Namen oder die Auswahl ist ungültig.")
            }
            let real = source.resolvingSymlinksInPath().path
            if destination.path == real || destination.path.hasPrefix(real + "/") {
                throw TransferFailure(message: "Ein Ordner kann nicht in sich selbst übertragen werden.")
            }
            for other in canonical where other != source {
                if source.path.hasPrefix(other.path + "/") {
                    throw TransferFailure(message: "Bitte nicht gleichzeitig einen Ordner und seinen Inhalt auswählen.")
                }
            }
            let target = destination.appendingPathComponent(source.lastPathComponent)
            guard !exists(target) else { throw TransferFailure(message: "Im Ziel existiert bereits: \(source.lastPathComponent). Nichts wurde überschrieben.") }
        }
        return canonical.map { ($0, destination.appendingPathComponent($0.lastPathComponent)) }
    }
    func execute(_ plan: [(URL, URL)], move: Bool, progress: (Int, String) -> Void) throws {
        for (index, pair) in plan.enumerated() {
            progress(index, pair.0.lastPathComponent)
            do {
                // Apple's moveItem copies then removes the source across volumes.
                // Never add a separate removeItem fallback: errors can be partial.
                if move { try fm.moveItem(atPath: pair.0.path, toPath: pair.1.path) }
                else { try fm.copyItem(atPath: pair.0.path, toPath: pair.1.path) }
                guard exists(pair.1), !move || !exists(pair.0) else {
                    throw TransferFailure(message: "Quell-/Zielzustand konnte nicht bestätigt werden.")
                }
            } catch {
                throw TransferFailure(message: "\(index) von \(plan.count) Objekten abgeschlossen. Fehler bei \(pair.0.lastPathComponent): \(error.localizedDescription)\nBitte Quelle und Ziel prüfen. Keine automatische Wiederholung oder zusätzliche Löschung.")
            }
        }
    }
}
