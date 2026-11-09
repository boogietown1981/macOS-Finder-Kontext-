import Foundation
let fm = FileManager.default
let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try fm.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: root) }
let from = root.appendingPathComponent("source"), to = root.appendingPathComponent("target")
try fm.createDirectory(at: from, withIntermediateDirectories: true)
try fm.createDirectory(at: to, withIntermediateDirectories: true)
let engine = TransferEngine()
func file(_ name: String) throws -> URL {
    let u = from.appendingPathComponent(name); try Data("Test äöü".utf8).write(to:u); return u
}
func mustReject(_ block: () throws -> Void) {
    do { try block(); fatalError("Expected rejection") } catch { }
}
let one = try file("A 'quoted' ü.txt")
try engine.execute(engine.plan([one], into: to), move: true) { _,_ in }
assert(!engine.exists(one)); assert(engine.exists(to.appendingPathComponent(one.lastPathComponent)))
let two = try file("copy.txt")
try engine.execute(engine.plan([two], into: to), move: false) { _,_ in }
assert(engine.exists(two))
mustReject { _ = try engine.plan([two], into: to) }
mustReject { _ = try engine.plan([from], into: from) }
mustReject { _ = try engine.plan([from,two], into: to) }
let brokenLink = from.appendingPathComponent("link")
try fm.createSymbolicLink(atPath:brokenLink.path,withDestinationPath:"missing-target")
try engine.execute(engine.plan([brokenLink], into: to), move: true) { _,_ in }
assert(!engine.exists(brokenLink)); assert(engine.exists(to.appendingPathComponent("link")))
let conflict = try file("race.txt")
let race = try engine.plan([conflict], into: to)
try Data("original".utf8).write(to:to.appendingPathComponent("race.txt"))
mustReject { try engine.execute(race,move:true) { _,_ in } }
assert(engine.exists(conflict)); let unchanged = try String(contentsOf:to.appendingPathComponent("race.txt")); assert(unchanged == "original")
if CommandLine.arguments.count > 1 {
    let other = URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at:other,withIntermediateDirectories:true)
    defer { try? fm.removeItem(at:other) }
    let cross = try file("cross-volume.txt")
    try engine.execute(engine.plan([cross],into:other),move:true) { _,_ in }
    assert(!engine.exists(cross)); assert(engine.exists(other.appendingPathComponent(cross.lastPathComponent)))
    print("Cross-volume move: source removed, target exists")
}
print("Move, copy, conflicts, nesting, symlink and race tests passed")
