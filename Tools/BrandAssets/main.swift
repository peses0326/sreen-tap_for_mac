// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import ScreenTapCore

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("site/assets")
let iconset = root.appendingPathComponent(".build/ScreenTap.iconset")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func bitmap(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func fill(_ context: CGContext, _ rect: CGRect, _ color: CGColor, radius: CGFloat = 0) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.fillPath()
}
func text(_ context: CGContext, _ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ hex: UInt32, mono: Bool = false) {
    let font = CTFontCreateWithName((mono ? "Menlo" : "Helvetica") as CFString, size, nil)
    let string = NSAttributedString(string: value, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(hex)])
    let line = CTLineCreateWithAttributedString(string)
    context.saveGState(); context.translateBy(x: x, y: y + size); context.scaleBy(x: 1, y: -1)
    context.textMatrix = .identity; context.textPosition = .zero; CTLineDraw(line, context); context.restoreGState()
}
func write(_ image: CGImage, _ url: URL) throws {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}
func appIcon(_ size: Int) -> CGImage {
    let c = bitmap(size, size)
    c.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    c.translateBy(x: 0, y: 1024); c.scaleBy(x: 1, y: -1)
    let outer = CGPath(roundedRect: CGRect(x: 48, y: 48, width: 928, height: 928), cornerWidth: 216, cornerHeight: 216, transform: nil)
    c.saveGState(); c.addPath(outer); c.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0x163D4C), color(0x071C29)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(gradient, start: CGPoint(x: 80, y: 60), end: CGPoint(x: 900, y: 1000), options: [])
    c.restoreGState()
    fill(c, CGRect(x: 185, y: 226, width: 532, height: 382), color(0x7CA5AF, 0.3), radius: 54)
    fill(c, CGRect(x: 250, y: 306, width: 532, height: 382), color(0x789FAC, 0.5), radius: 54)
    let front = CGPath(roundedRect: CGRect(x: 315, y: 386, width: 532, height: 382), cornerWidth: 54, cornerHeight: 54, transform: nil)
    c.saveGState(); c.addPath(front); c.clip()
    let mint = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0xD0FFF0), color(0x57E6BD)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(mint, start: CGPoint(x: 320, y: 390), end: CGPoint(x: 800, y: 760), options: [])
    c.restoreGState()
    c.setStrokeColor(color(0x163D4C, 0.35)); c.setLineWidth(16)
    c.move(to: CGPoint(x: 315, y: 480)); c.addLine(to: CGPoint(x: 847, y: 480)); c.strokePath()
    fill(c, CGRect(x: 351, y: 421, width: 26, height: 26), color(0x163D4C), radius: 13)
    fill(c, CGRect(x: 392, y: 421, width: 26, height: 26), color(0x163D4C, 0.5), radius: 13)
    c.setStrokeColor(color(0x0B3542)); c.setLineWidth(40); c.setLineCap(.round); c.setLineJoin(.round)
    c.move(to: CGPoint(x: 485, y: 560)); c.addLine(to: CGPoint(x: 688, y: 560)); c.strokePath()
    c.move(to: CGPoint(x: 633, y: 505)); c.addLine(to: CGPoint(x: 690, y: 560)); c.addLine(to: CGPoint(x: 633, y: 615)); c.strokePath()
    return c.makeImage()!
}
func demoIcon(_ index: Int) -> CGImage {
    let c = bitmap(56, 56)
    let colors: [UInt32] = [0x43B2D1, 0x243D4C, 0xB999EF, 0xFAAE69, 0xE9D27E, 0x79C9B1, 0xF08CA5, 0x69A5DC]
    fill(c, CGRect(x: 2, y: 2, width: 52, height: 52), color(colors[index]), radius: 13)
    c.setStrokeColor(color(0xFFFFFF, 0.9)); c.setLineWidth(3)
    c.stroke(CGRect(x: 15, y: 16, width: 26, height: 22))
    c.move(to: CGPoint(x: 15, y: 30)); c.addLine(to: CGPoint(x: 41, y: 30)); c.strokePath()
    return c.makeImage()!
}
func demoWindow(_ index: Int) -> CGImage {
    let c = bitmap(480, 300)
    c.translateBy(x: 0, y: 300); c.scaleBy(x: 1, y: -1)
    fill(c, CGRect(x: 0, y: 0, width: 480, height: 300), color(index == 1 || index == 5 ? 0x11232E : 0xEFF2EC), radius: 10)
    fill(c, CGRect(x: 0, y: 0, width: 480, height: 28), color(0xDCE3DF), radius: 8)
    for (i, hex) in [UInt32(0xF07870),0xEDC065,0x6DC38B].enumerated() {
        fill(c, CGRect(x: 12 + i * 15, y: 10, width: 7, height: 7), color(hex), radius: 4)
    }
    switch index {
    case 0:
        text(c, "Make room for your next thought.", 28, 58, 21, 0x163D4C)
        text(c, "ScreenTap / Your windows, one shortcut away.", 28, 92, 11, 0x52756C)
        for i in 0..<3 { fill(c, CGRect(x: 28 + i * 144, y: 140, width: 130, height: 118), color([0xC7E7DB,0xD8D5EB,0xEAD9C5][i]), radius: 12) }
        text(c, "01   SEE", 40, 160, 13, 0x163D4C); text(c, "02   CHOOSE", 184, 160, 13, 0x163D4C); text(c, "03   GO", 328, 160, 13, 0x163D4C)
    case 1:
        for (i, line) in ["~/Projects/screentap", "$ swift build -c release", "Building for production...", "Build complete.", "", "$ ./scripts/test.sh", "16 checks, 0 failures", "", "$ _"].enumerated() {
            text(c, line, 22, 45 + CGFloat(i) * 25, 13, i == 6 ? 0x73ECC0 : 0xB2C6CE, mono: true)
        }
    case 2:
        fill(c, CGRect(x: 0, y: 28, width: 120, height: 272), color(0xD6CCE5))
        text(c, "Studio", 16, 48, 16, 0x40314D)
        for (i, line) in ["# general", "# design", "# releases"].enumerated() { text(c, line, 16, 92 + CGFloat(i) * 35, 12, 0x655771) }
        text(c, "Product / Design", 140, 45, 17, 0x163D4C)
        for (i, line) in ["Mina    10:24", "The new window grid is ready.", "Alex     10:26", "Looks good. Let's ship it."].enumerated() { text(c, line, 140, 100 + CGFloat(i) * 32, 12, 0x52756C) }
    case 3:
        text(c, "November 2026", 24, 46, 20, 0x163D4C)
        for column in 0..<5 {
            text(c, ["MON 9","TUE 10","WED 11","THU 12","FRI 13"][column], 24 + CGFloat(column) * 90, 89, 10, 0x52756C)
            for row in 0..<4 { fill(c, CGRect(x: 22 + column * 90, y: 115 + row * 39, width: 86, height: 35), color(0xE0E7DE), radius: 3) }
        }
        fill(c, CGRect(x: 24, y: 119, width: 82, height: 68), color(0xB7DDCD), radius: 5)
        text(c, "Focus time", 31, 130, 10, 0x163D4C)
    case 4:
        text(c, "Ideas for the week", 32, 52, 24, 0x163D4C)
        for (i, line) in ["A little less friction.", "A little more focus.", "", "• Keep the shortcut familiar", "• Make each window recognizable", "• Give memory back when done"].enumerated() { text(c, line, 32, 101 + CGFloat(i) * 26, 14, 0x52756C) }
    case 5:
        for (i, line) in ["enum SwitcherRenderer {", "  static func draw(in context: CGContext) {", "    let windows = recentWindows()", "    for window in windows {", "      drawThumbnail(window)", "    }", "  }", "}"].enumerated() { text(c, line, 20, 45 + CGFloat(i) * 27, 12, i == 0 ? 0xB7A6E8 : 0x83DDBB, mono: true) }
    case 6:
        fill(c, CGRect(x: 30, y: 55, width: 160, height: 190), color(0xA2C9BB), radius: 15)
        text(c, "FOCUS", 45, 102, 27, 0x163D4C); text(c, "A quieter afternoon", 213, 79, 17, 0x163D4C)
        for i in 0..<5 { text(c, "0\(i + 1)   Track for a clear mind", 213, 120 + CGFloat(i) * 29, 10, 0x52756C) }
    default:
        text(c, "Screenshots", 24, 49, 20, 0x163D4C)
        for row in 0..<2 { for column in 0..<4 {
            fill(c, CGRect(x: 26 + column * 112, y: 96 + row * 92, width: 92, height: 60), color(0xBAD9D0), radius: 8)
            text(c, "Window \(row * 4 + column + 1)", 28 + CGFloat(column) * 112, 163 + CGFloat(row) * 92, 9, 0x52756C)
        } }
    }
    return c.makeImage()!
}

for size in [16,32,128,256,512] {
    try write(appIcon(size), iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try write(appIcon(size * 2), iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try write(appIcon(512), assets.appendingPathComponent("icon.png"))
let apps = ["Browser", "Terminal", "Team Chat", "Calendar", "Notes", "Editor", "Music", "Files"]
let titles = ["ScreenTap · overview", "~/Projects/screentap", "Product / Design", "Monday, 9 November", "Ideas for the week", "SwitcherRenderer.swift", "Focus playlist", "Screenshots"]
let cards = apps.enumerated().map { SwitcherCard(app: $0.element, title: titles[$0.offset], image: demoWindow($0.offset), icon: demoIcon($0.offset)) }
let grid = bitmap(2080, 944)
grid.scaleBy(x: 2, y: 2)
SwitcherRenderer.draw(in: grid, size: CGSize(width: 1040, height: 472), cards: cards, selected: 1, offset: 0, total: 8, columns: 4, status: "",
    hint: "Release ⌥ to switch    ⇧⇥ Reverse    ←↑↓→ Select    Esc or blank click Cancel")
try write(grid.makeImage()!, assets.appendingPathComponent("switcher-demo.png"))
print("Exported original app icons and production-rendered demo grid to site/assets")
