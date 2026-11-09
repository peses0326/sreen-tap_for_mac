import AppKit
import LeanTabCore

final class SwitcherView: NSView {
    override var isFlipped: Bool { true }
    var records: [WindowRecord] = []
    var selected = 0
    var offset = 0
    var total = 0
    var columns = 4
    var status = ""
    var image: ((WindowKey) -> CGImage?)?
    var choose: ((Int) -> Void)?
    var cancel: (() -> Void)?
    private var icons: [pid_t: NSImage] = [:]
    let cellHeight: CGFloat = 184

    func reset(records: [WindowRecord], selected: Int, offset: Int, total: Int, columns: Int) {
        self.records = records; self.selected = selected; self.offset = offset; self.total = total; self.columns = columns
        icons.removeAll()
        for record in records where icons[record.key.pid] == nil {
            if let source = NSRunningApplication(processIdentifier: record.key.pid)?.icon {
                // Rasterize one small representation rather than retaining all icon sizes.
                let icon = NSImage(size: NSSize(width: 28, height: 28))
                icon.lockFocus(); source.draw(in: NSRect(x: 0, y: 0, width: 28, height: 28)); icon.unlockFocus()
                icons[record.key.pid] = icon
            }
        }
        needsDisplay = true
    }

    func clear() { records.removeAll(); icons.removeAll(); image = nil; needsDisplay = true }

    private func cell(_ index: Int) -> NSRect {
        SwitcherHitTest.cell(index: index, width: bounds.width, columns: columns)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.07, alpha: 0.98).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 22, yRadius: 22).fill()
        text("LeanTab", rect: NSRect(x: 26, y: 19, width: 150, height: 24), size: 19, color: .white, bold: true)
        let counter = total == 0 ? "" : "\(selected + 1) / \(total)"
        text(counter, rect: NSRect(x: bounds.width - 120, y: 22, width: 92, height: 22), size: 13, color: .lightGray)
        if records.isEmpty {
            text(status, rect: NSRect(x: 28, y: 85, width: bounds.width - 56, height: 50), size: 14, color: .lightGray)
        }
        for (i, record) in records.enumerated() {
            let rect = cell(i)
            let active = i + offset == selected
            (active ? NSColor.controlAccentColor.withAlphaComponent(0.25) : NSColor.white.withAlphaComponent(0.055)).setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
            path.fill()
            if active { NSColor.controlAccentColor.setStroke(); path.lineWidth = 2.5; path.stroke() }
            let preview = NSRect(x: rect.minX + 9, y: rect.minY + 9, width: rect.width - 18, height: 116)
            if let cgImage = image?(record.key) {
                let ratio = min(preview.width / CGFloat(cgImage.width), preview.height / CGFloat(cgImage.height))
                let size = NSSize(width: CGFloat(cgImage.width) * ratio, height: CGFloat(cgImage.height) * ratio)
                let target = NSRect(x: preview.midX - size.width / 2, y: preview.midY - size.height / 2, width: size.width, height: size.height)
                let context = NSGraphicsContext.current!.cgContext
                context.saveGState()
                context.translateBy(x: target.minX, y: target.maxY)
                context.scaleBy(x: 1, y: -1)
                context.draw(cgImage, in: NSRect(origin: .zero, size: size))
                context.restoreGState()
            } else {
                icons[record.key.pid]?.draw(in: NSRect(x: preview.midX - 14, y: preview.midY - 14, width: 28, height: 28),
                    from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
            icons[record.key.pid]?.draw(in: NSRect(x: rect.minX + 10, y: rect.minY + 132, width: 18, height: 18),
                from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            let badge = record.minimized ? L.text(" · 최소화", " · Minimized") : (record.hidden ? L.text(" · 숨김", " · Hidden") : "")
            text(record.appName + badge, rect: NSRect(x: rect.minX + 34, y: rect.minY + 132, width: rect.width - 43, height: 20), size: 12, color: .white, bold: true)
            text(record.title.isEmpty ? record.appName : record.title,
                 rect: NSRect(x: rect.minX + 10, y: rect.minY + 153, width: rect.width - 20, height: 18), size: 11, color: .lightGray)
        }
        let hint = status.isEmpty ? L.text("⌥ 놓기: 전환   ⇧⇥: 역순   방향키: 선택   Esc/여백 클릭: 취소   ⌘W: 닫기   ⌘M: 최소화", "Release ⌥ to switch   ⇧⇥: reverse   Arrows: select   Esc/blank click: cancel   ⌘W: close   ⌘M: minimize") : status
        text(hint, rect: NSRect(x: 26, y: bounds.height - 29, width: bounds.width - 52, height: 21), size: 11, color: .lightGray)
    }

    private func text(_ value: String, rect: NSRect, size: CGFloat, color: NSColor, bold: Bool = false) {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
        (value as NSString).draw(in: rect, withAttributes: [.font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
            .foregroundColor: color, .paragraphStyle: style])
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch SwitcherHitTest.click(at: point, width: bounds.width, columns: columns, count: records.count, offset: offset) {
        case .select(let index): choose?(index)
        case .cancel: cancel?()
        }
    }
}
