// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import AppKit
import ScreenTapCore

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
    private var icons: [pid_t: CGImage] = [:]

    func reset(records: [WindowRecord], selected: Int, offset: Int, total: Int, columns: Int) {
        self.records = records; self.selected = selected; self.offset = offset; self.total = total; self.columns = columns
        icons.removeAll()
        for record in records where icons[record.key.pid] == nil {
            guard let source = NSRunningApplication(processIdentifier: record.key.pid)?.icon else { continue }
            let icon = NSImage(size: NSSize(width: 28, height: 28))
            icon.lockFocus(); source.draw(in: NSRect(x: 0, y: 0, width: 28, height: 28)); icon.unlockFocus()
            icons[record.key.pid] = icon.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        needsDisplay = true
    }
    func clear() { records.removeAll(); icons.removeAll(); image = nil; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let cards = records.map { record in
            SwitcherCard(app: record.appName, title: record.title,
                badge: record.minimized ? L.text(" · 최소화", " · Minimized") : (record.hidden ? L.text(" · 숨김", " · Hidden") : ""),
                image: image?(record.key), icon: icons[record.key.pid])
        }
        let hint = L.text("⌥ 놓기: 전환   ⇧⇥: 역순   방향키: 선택   Esc/여백 클릭: 취소   ⌘W: 닫기   ⌘M: 최소화",
                          "Release ⌥ to switch   ⇧⇥: reverse   Arrows: select   Esc/blank click: cancel   ⌘W: close   ⌘M: minimize")
        // NSView has already flipped its drawing context; normalize it for the shared renderer.
        context.saveGState(); context.translateBy(x: 0, y: bounds.height); context.scaleBy(x: 1, y: -1)
        SwitcherRenderer.draw(in: context, size: bounds.size, cards: cards, selected: selected, offset: offset,
                              total: total, columns: columns, status: status, hint: hint)
        context.restoreGState()
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch SwitcherHitTest.click(at: point, width: bounds.width, columns: columns, count: records.count, offset: offset) {
        case .select(let index): choose?(index)
        case .cancel: cancel?()
        }
    }
}
