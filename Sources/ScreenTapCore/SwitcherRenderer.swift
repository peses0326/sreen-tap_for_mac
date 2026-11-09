// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import Foundation
import CoreGraphics
import CoreText

public struct SwitcherCard {
    public let app: String
    public let title: String
    public let badge: String
    public let image: CGImage?
    public let icon: CGImage?
    public init(app: String, title: String, badge: String = "", image: CGImage?, icon: CGImage?) {
        self.app = app; self.title = title; self.badge = badge; self.image = image; self.icon = icon
    }
}

// The live NSView and marketing exports use the same renderer. Exported demo
// content is labelled separately; no user's windows are captured for marketing.
public enum SwitcherRenderer {
    private static let ink = color(0.91, 0.96, 0.95)
    private static let secondary = color(0.55, 0.67, 0.70)
    private static let accent = color(0.43, 0.94, 0.76)
    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    private static func fill(_ rect: CGRect, radius: CGFloat, color: CGColor, in context: CGContext) {
        context.setFillColor(color)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.fillPath()
    }
    public static func draw(in context: CGContext, size: CGSize, cards: [SwitcherCard], selected: Int,
                            offset: Int, total: Int, columns: Int, status: String, hint: String) {
        context.saveGState()
        context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
        fill(CGRect(origin: .zero, size: size), radius: 22, color: color(0.035, 0.075, 0.095, 0.99), in: context)
        text("ScreenTap", rect: CGRect(x: 26, y: 18, width: 180, height: 25), size: 19, bold: true, color: ink, in: context)
        if total > 0 { text("\(selected + 1) / \(total)", rect: CGRect(x: size.width - 114, y: 23, width: 90, height: 20), size: 12, color: secondary, in: context) }
        if cards.isEmpty { text(status, rect: CGRect(x: 28, y: 86, width: size.width - 56, height: 50), size: 14, color: secondary, in: context) }
        for (index, card) in cards.enumerated() {
            let rect = SwitcherHitTest.cell(index: index, width: size.width, columns: columns)
            let active = index + offset == selected
            fill(rect, radius: 12, color: active ? color(0.10, 0.23, 0.23) : color(0.075, 0.12, 0.14), in: context)
            if active {
                context.setStrokeColor(accent); context.setLineWidth(2)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)); context.strokePath()
            }
            let preview = CGRect(x: rect.minX + 9, y: rect.minY + 9, width: rect.width - 18, height: 116)
            if let image = card.image { drawImage(image, in: preview, context: context) }
            else if let icon = card.icon { drawImage(icon, in: CGRect(x: preview.midX - 17, y: preview.midY - 17, width: 34, height: 34), context: context) }
            if let icon = card.icon { drawImage(icon, in: CGRect(x: rect.minX + 10, y: rect.minY + 132, width: 18, height: 18), context: context) }
            text(card.app + card.badge, rect: CGRect(x: rect.minX + 34, y: rect.minY + 132, width: rect.width - 43, height: 20), size: 12, bold: true, color: ink, in: context)
            text(card.title.isEmpty ? card.app : card.title, rect: CGRect(x: rect.minX + 10, y: rect.minY + 153, width: rect.width - 20, height: 18), size: 11, color: secondary, in: context)
        }
        text(status.isEmpty ? hint : status, rect: CGRect(x: 26, y: size.height - 30, width: size.width - 52, height: 22), size: 11, color: secondary, in: context)
        context.restoreGState()
    }
    private static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        let scale = min(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        context.saveGState()
        context.translateBy(x: rect.midX - size.width / 2, y: rect.midY + size.height / 2); context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: size))
        context.restoreGState()
    }
    private static func text(_ value: String, rect: CGRect, size: CGFloat, bold: Bool = false, color: CGColor, in context: CGContext) {
        let base = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let font = bold ? CTFontCreateCopyWithSymbolicTraits(base, size, nil, .boldTrait, .boldTrait) ?? base : base
        let attributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: attributes))
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: attributes))
        let fitted = CTLineCreateTruncatedLine(line, rect.width, .end, ellipsis) ?? line
        context.saveGState(); context.translateBy(x: rect.minX, y: rect.minY + size + 1); context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity; context.textPosition = .zero; CTLineDraw(fitted, context); context.restoreGState()
    }
}
