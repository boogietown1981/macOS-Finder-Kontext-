import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
        NSColor(srgbRed: 0.10, green: 0.16, blue: 0.21, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204).fill()
        let folder = NSBezierPath()
        folder.move(to: NSPoint(x: 230, y: 282)); folder.line(to: NSPoint(x: 794, y: 282))
        folder.line(to: NSPoint(x: 794, y: 680)); folder.line(to: NSPoint(x: 466, y: 680))
        folder.line(to: NSPoint(x: 408, y: 736)); folder.line(to: NSPoint(x: 230, y: 736)); folder.close()
        NSColor(srgbRed: 0.43, green: 0.64, blue: 0.73, alpha: 1).setFill(); folder.fill()
        NSColor(srgbRed: 0.93, green: 0.97, blue: 0.98, alpha: 1).setStroke()
        let arrows = NSBezierPath(); arrows.lineWidth = 32; arrows.lineCapStyle = .round; arrows.lineJoinStyle = .round
        for points in [[NSPoint(x:340,y:550),NSPoint(x:660,y:550),NSPoint(x:610,y:600)], [NSPoint(x:660,y:550),NSPoint(x:610,y:500)], [NSPoint(x:684,y:408),NSPoint(x:364,y:408),NSPoint(x:414,y:458)], [NSPoint(x:364,y:408),NSPoint(x:414,y:358)]] {
            arrows.move(to: points[0]); for p in points.dropFirst() { arrows.line(to:p) }
        }
        arrows.stroke(); image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name))
    }
}
