// Original SlapBook Pro vector artwork. Run: swift Tools/generate_app_icon.swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let directory = root.appendingPathComponent("SlapBook/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func fill(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func drawIcon(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(size) / 1024)
    (transform as NSAffineTransform).concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 22, y: 22, width: 980, height: 980), xRadius: 218, yRadius: 218)
    NSGradient(starting: color(0.62, 0.46, 0.98), ending: color(0.35, 0.22, 0.69))!.draw(in: background, angle: -65)
    color(1, 1, 1, 0.08).setFill()
    NSBezierPath(ovalIn: NSRect(x: 95, y: 130, width: 840, height: 840)).fill()
    color(0.15, 0.07, 0.31, 0.22).setFill()
    NSBezierPath(ovalIn: NSRect(x: 182, y: 165, width: 650, height: 80)).fill()
    let ink = color(0.22, 0.14, 0.37)
    fill(NSRect(x: 234, y: 343, width: 556, height: 418), radius: 43, color: color(0.84, 0.81, 0.92))
    ink.setStroke()
    let lid = NSBezierPath(roundedRect: NSRect(x: 234, y: 343, width: 556, height: 418), xRadius: 43, yRadius: 43)
    lid.lineWidth = 10; lid.stroke()
    let screen = NSBezierPath(roundedRect: NSRect(x: 260, y: 375, width: 504, height: 357), xRadius: 23, yRadius: 23)
    NSGradient(starting: color(0.92, 0.87, 1), ending: color(0.79, 0.72, 0.98))!.draw(in: screen, angle: -80)
    fill(NSRect(x: 505, y: 741, width: 12, height: 6), radius: 3, color: ink.withAlphaComponent(0.6))
    let shine = NSBezierPath()
    shine.move(to: NSPoint(x: 281, y: 710)); shine.line(to: NSPoint(x: 422, y: 710)); shine.line(to: NSPoint(x: 281, y: 571)); shine.close()
    color(1, 1, 1, 0.25).setFill(); shine.fill()
    for x: CGFloat in [413, 578] { fill(NSRect(x: x, y: 547, width: 31, height: 47), radius: 16, color: ink) }
    for x: CGFloat in [346, 624] {
        color(0.97, 0.43, 0.57, 0.35).setFill(); NSBezierPath(ovalIn: NSRect(x: x, y: 493, width: 61, height: 27)).fill()
    }
    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: 467, y: 501))
    mouth.curve(to: NSPoint(x: 557, y: 501), controlPoint1: NSPoint(x: 485, y: 449), controlPoint2: NSPoint(x: 539, y: 449))
    mouth.lineWidth = 14; mouth.lineCapStyle = .round; ink.setStroke(); mouth.stroke()
    let base = NSBezierPath()
    base.move(to: NSPoint(x: 234, y: 343)); base.line(to: NSPoint(x: 790, y: 343))
    base.line(to: NSPoint(x: 879, y: 237))
    base.curve(to: NSPoint(x: 849, y: 205), controlPoint1: NSPoint(x: 891, y: 216), controlPoint2: NSPoint(x: 874, y: 205))
    base.line(to: NSPoint(x: 175, y: 205))
    base.curve(to: NSPoint(x: 145, y: 237), controlPoint1: NSPoint(x: 150, y: 205), controlPoint2: NSPoint(x: 133, y: 216))
    base.close()
    NSGradient(starting: color(0.93, 0.90, 0.99), ending: color(0.67, 0.61, 0.79))!.draw(in: base, angle: -90)
    ink.setStroke(); base.lineWidth = 8; base.stroke()
    for row in 0..<3 {
        for column in 0..<11 {
            fill(NSRect(x: 298 + CGFloat(column) * 39 - CGFloat(row) * 6, y: 310 - CGFloat(row) * 15, width: 29, height: 8), radius: 2, color: ink.withAlphaComponent(0.24))
        }
    }
    let trackpad = NSBezierPath(roundedRect: NSRect(x: 450, y: 231, width: 124, height: 27), xRadius: 5, yRadius: 5)
    ink.withAlphaComponent(0.25).setStroke(); trackpad.lineWidth = 2; trackpad.stroke()
    // A small orange spark: unreasonable enthusiasm, in four points.
    let spark = NSBezierPath()
    for (index, point) in [NSPoint(x: 840, y: 839), NSPoint(x: 855, y: 796), NSPoint(x: 898, y: 781), NSPoint(x: 855, y: 766), NSPoint(x: 840, y: 723), NSPoint(x: 825, y: 766), NSPoint(x: 782, y: 781), NSPoint(x: 825, y: 796)].enumerated() {
        if index == 0 { spark.move(to: point) } else { spark.line(to: point) }
    }
    spark.close(); color(1, 0.69, 0.39).setFill(); spark.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for logical in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(logical)\(scale == 2 ? "@2x" : "").png"
        try drawIcon(size: logical * scale).write(to: directory.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(logical)x\(logical)"])
    }
}
let manifest: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try data.write(to: directory.appendingPathComponent("Contents.json"))
print("Generated original MacBook mascot icon at all macOS sizes.")
