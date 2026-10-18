// Run: swift Tools/GenerateIcon.swift BabyHero/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let width = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: width,
                              bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(srgbRed: 0.624, green: 0.302, blue: 0.212, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: width)).fill()
for radius in [300.0, 395.0] {
    NSColor(srgbRed: 0.98, green: 0.965, blue: 0.937, alpha: 0.12).setStroke()
    let path = NSBezierPath(ovalIn: NSRect(x: 512 - radius, y: 512 - radius, width: radius * 2, height: radius * 2))
    path.lineWidth = 3
    path.stroke()
}
for index in 0..<9 {
    let heights: [Double] = [86, 158, 242, 326, 398, 326, 242, 158, 86]
    let height = heights[index]
    NSColor(srgbRed: 0.98, green: 0.965, blue: 0.937, alpha: index == 4 ? 1 : 0.85).setFill()
    NSBezierPath(roundedRect: NSRect(x: 237 + Double(index) * 64, y: 512 - height / 2,
                                    width: 38, height: height), xRadius: 19, yRadius: 19).fill()
}
let star = NSBezierPath()
star.move(to: NSPoint(x: 776, y: 788))
star.curve(to: NSPoint(x: 826, y: 738), controlPoint1: NSPoint(x: 780, y: 749), controlPoint2: NSPoint(x: 787, y: 742))
star.curve(to: NSPoint(x: 776, y: 688), controlPoint1: NSPoint(x: 787, y: 734), controlPoint2: NSPoint(x: 780, y: 727))
star.curve(to: NSPoint(x: 726, y: 738), controlPoint1: NSPoint(x: 772, y: 727), controlPoint2: NSPoint(x: 765, y: 734))
star.curve(to: NSPoint(x: 776, y: 788), controlPoint1: NSPoint(x: 765, y: 742), controlPoint2: NSPoint(x: 772, y: 749))
star.close()
NSColor(srgbRed: 0.945, green: 0.843, blue: 0.776, alpha: 1).setFill()
star.fill()
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
