// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import AppKit
import ApplicationServices
import ScreenTapCore
import Darwin

final class AppController: NSObject, NSApplicationDelegate {
    private let windows = WindowService()
    private let thumbnails = ThumbnailService()
    private let hotkey = HotKey()
    private var item: NSStatusItem!
    private var panel: NSPanel?
    private var view: SwitcherView?
    private var records: [WindowRecord] = []
    private var selection = Selection()
    private var session: UInt64 = 0
    private var visible = false
    private var loading = false
    private var pendingSteps = 0
    private var released = false
    private var commitOnOptionRelease = false
    private var page = -1
    private var pageSize = 12
    private var columns = 4
    private var permissionWindow: NSWindow?
    private var consumedKeys: Set<Int64> = []
    private var consumedMouseUps: Set<CGEventType> = []
    private var workspaceTokens: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--render-preview") {
            renderPreview()
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = menuIcon()
        rebuildMenu()
        hotkey.handle = { [weak self] type, event in self?.handle(type, event) ?? false }
        hotkey.disabled = { [weak self] in self?.dismiss() }
        thumbnails.onPressure = { [weak self] in
            self?.view?.status = L.text("메모리 압력으로 미리보기를 비웠습니다", "Previews cleared to relieve memory pressure")
            self?.view?.needsDisplay = true
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.dismiss() })
        }
        if AXIsProcessTrusted() { windows.start() }
        let ready = hotkey.start()
        if !ready || !AXIsProcessTrusted() || !CGPreflightScreenCaptureAccess() { showPermissions() }
        if CommandLine.arguments.contains("--preview") { showPreview() }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        func add(_ title: String, _ selector: Selector) {
            let entry = NSMenuItem(title: title, action: selector, keyEquivalent: ""); entry.target = self; menu.addItem(entry)
        }
        add(L.text("창 전환기 열기", "Open window switcher"), #selector(openFromMenu))
        add(L.text("권한 설정 / 다시 연결", "Permissions / Reconnect"), #selector(reconnect))
        add(L.text("메모리 진단 복사", "Copy memory diagnostics"), #selector(copyDiagnostics))
        add(L.text("ScreenTap 정보", "About ScreenTap"), #selector(showAbout))
        menu.addItem(.separator())
        let language = NSMenuItem(title: L.text("언어", "Language"), action: nil, keyEquivalent: "")
        let languages = NSMenu()
        for (code, name) in [("auto", "시스템 / System"), ("ko", "한국어"), ("en", "English")] {
            let entry = NSMenuItem(title: name, action: #selector(setLanguage(_:)), keyEquivalent: "")
            entry.target = self; entry.representedObject = code; entry.state = L.language == code ? .on : .off
            languages.addItem(entry)
        }
        language.submenu = languages; menu.addItem(language)
        menu.addItem(.separator())
        add(L.text("ScreenTap 종료", "Quit ScreenTap"), #selector(quit))
        item.menu = menu
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.representedObject as? String, forKey: "language")
        dismiss(); rebuildMenu()
        if permissionWindow != nil { permissionWindow?.close(); permissionWindow = nil; showPermissions() }
    }
    private func menuIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18))
        image.lockFocus()
        NSColor.black.setStroke()
        let back = NSBezierPath(roundedRect: NSRect(x: 1, y: 6, width: 13, height: 10), xRadius: 2, yRadius: 2)
        back.lineWidth = 1.2; back.stroke()
        let front = NSBezierPath(roundedRect: NSRect(x: 5, y: 2, width: 14, height: 11), xRadius: 2, yRadius: 2)
        NSColor.white.setFill(); front.fill(); front.lineWidth = 1.2; front.stroke()
        let arrow = NSBezierPath(); arrow.lineWidth = 1.4; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
        arrow.move(to: NSPoint(x: 8, y: 7.5)); arrow.line(to: NSPoint(x: 15.5, y: 7.5))
        arrow.move(to: NSPoint(x: 12.5, y: 10)); arrow.line(to: NSPoint(x: 15.5, y: 7.5)); arrow.line(to: NSPoint(x: 12.5, y: 5))
        arrow.stroke(); image.unlockFocus(); image.isTemplate = true
        image.accessibilityDescription = "ScreenTap"
        return image
    }
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "ScreenTap", .applicationVersion: "0.2.0",
            .credits: NSAttributedString(string: L.text("창을 보고, 선택하고, 하던 일을 이어가세요.\nAltTab에서 영감을 받아 별도로 작성했습니다.", "See your windows. Keep your flow.\nInspired by AltTab; independently written."))])
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func reconnect() {
        if AXIsProcessTrusted() { windows.start() }
        _ = hotkey.start()
        showPermissions()
    }
    @objc private func openFromMenu() {
        guard AXIsProcessTrusted() else { showPermissions(); return }
        summon(step: 0)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .leftMouseUp || type == .rightMouseUp {
            return consumedMouseUps.remove(type) != nil
        }
        if type == .leftMouseDown || type == .rightMouseDown {
            guard visible else { return false }
            consumedMouseUps.insert(type == .leftMouseDown ? .leftMouseUp : .rightMouseUp)
            guard type == .leftMouseDown, let panel, let view,
                  panel.frame.contains(NSEvent.mouseLocation) else {
                dismiss(); return true
            }
            // Handle the click before modifier release, without waiting for AppKit
            // to deliver mouseDown to a nonactivating panel's first responder.
            let mouse = NSEvent.mouseLocation
            let point = CGPoint(x: mouse.x - panel.frame.minX, y: panel.frame.maxY - mouse.y)
            switch SwitcherHitTest.click(at: point, width: view.bounds.width, columns: columns,
                                        count: view.records.count, offset: view.offset) {
            case .select(let index): selection.select(index); commit()
            case .cancel: dismiss()
            }
            return true
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let option = event.flags.contains(.maskAlternate)
        if type == .flagsChanged {
            if visible && commitOnOptionRelease && !option {
                if loading { released = true } else { commit() }
            }
            return false
        }
        if type == .keyUp { return consumedKeys.remove(key) != nil }
        guard type == .keyDown else { return false }
        if key == 48 && option && !event.flags.contains(.maskCommand) && !event.flags.contains(.maskControl) {
            guard AXIsProcessTrusted() else { return false }
            let step = event.flags.contains(.maskShift) ? -1 : 1
            if visible {
                if loading { pendingSteps += step } else { selection.move(step); render() }
            } else { summon(step: step) }
            consumedKeys.insert(key); return true
        }
        guard visible else { return false }
        // Keep unrelated shortcuts out of the previously focused application while cycling.
        if key == 53 { dismiss() }
        else if key == 36 || key == 76 { if loading { released = true } else { commit() } }
        else if [123, 124, 125, 126, 48].contains(key) {
            let delta: Int
            switch key {
            case 123: delta = -1
            case 124: delta = 1
            case 125: delta = columns
            case 126: delta = -columns
            default: delta = event.flags.contains(.maskShift) ? -1 : 1
            }
            if loading { pendingSteps += delta } else { selection.move(delta); render() }
        } else if event.flags.contains(.maskCommand), (key == 13 || key == 46), !loading, !records.isEmpty {
            let record = records[selection.index]
            windows.perform(key == 13 ? "close" : "minimize", on: record)
            dismiss()
        }
        consumedKeys.insert(key); return true
    }

    private func summon(step: Int) {
        dismiss()
        session += 1
        let token = session
        visible = true; loading = true; pendingSteps = step; released = false
        commitOnOptionRelease = step != 0
        createPanel()
        view?.status = L.text("열린 창을 가져오는 중…", "Loading open windows…")
        view?.needsDisplay = true
        panel?.orderFrontRegardless()
        windows.snapshot { [weak self] records in
            guard let self, self.visible, token == self.session else { return }
            self.records = records
            self.selection.reset(count: records.count, selectPrevious: false)
            self.selection.move(self.pendingSteps)
            self.loading = false
            if self.released { self.commit(); return }
            self.view?.status = records.isEmpty ? L.text("전환할 창이 없습니다. 접근성 권한을 확인하세요.", "No windows found. Check Accessibility permission.") : ""
            self.render()
        }
    }

    private func createPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main!
        let area = screen.visibleFrame
        columns = max(1, min(4, Int((area.width - 60) / 230)))
        let rows = max(1, min(3, Int((area.height - 140) / 184)))
        pageSize = columns * rows
        let size = NSSize(width: min(area.width - 36, CGFloat(columns) * 250 + 40), height: CGFloat(rows) * 184 + 104)
        let rect = NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        let view = SwitcherView(frame: NSRect(origin: .zero, size: size))
        view.choose = { [weak self] index in self?.selection.select(index); self?.commit() }
        view.cancel = { [weak self] in self?.dismiss() }
        view.image = { [weak thumbnails] key in thumbnails?.cache.value(for: key) }
        panel.contentView = view; self.panel = panel; self.view = view
    }

    private func render() {
        guard visible, let view else { return }
        let nextPage = selection.index / pageSize
        let offset = nextPage * pageSize
        let visibleRecords = Array(records.dropFirst(offset).prefix(pageSize))
        if page != nextPage {
            page = nextPage
            view.reset(records: visibleRecords, selected: selection.index, offset: offset, total: records.count, columns: columns)
            thumbnails.load(visibleRecords, onImage: { [weak self] in self?.view?.needsDisplay = true }, onStatus: { [weak self] status in
                self?.view?.status = status; self?.view?.needsDisplay = true
            })
        } else { view.selected = selection.index; view.needsDisplay = true }
    }

    private func commit() {
        guard visible, !loading, records.indices.contains(selection.index) else { dismiss(); return }
        let record = records[selection.index]
        dismiss()
        // Let the panel's orderOut commit before any AX IPC or activation occurs.
        DispatchQueue.main.async { [weak self] in
            self?.windows.focus(record) { success in
                if !success { NSSound.beep() }
            }
        }
    }

    private func dismiss() {
        session += 1; visible = false; loading = false; released = false; commitOnOptionRelease = false; page = -1
        panel?.orderOut(nil)
        view?.clear(); panel?.contentView = nil
        panel = nil; view = nil; records.removeAll()
        thumbnails.clear()
    }

    @objc private func showPermissions() {
        if let permissionWindow { permissionWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 590, height: 380),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "ScreenTap"; window.isReleasedWhenClosed = false; window.center()
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 590, height: 380))
        let title = NSTextField(labelWithString: L.text("가벼운 창 전환, 필요한 권한 두 가지", "Lightweight window switching"))
        title.font = .boldSystemFont(ofSize: 22); title.frame = NSRect(x: 28, y: 318, width: 540, height: 32); root.addSubview(title)
        let description = NSTextField(wrappingLabelWithString: L.text(
            "접근성: ⌥Tab 단축키와 개별 창 전환\n화면 및 시스템 오디오 기록: 창 미리보기 이미지\n\n기존 AltTab의 단축키를 끄거나 앱을 종료한 뒤 사용하세요.\n권한 변경 후 ScreenTap을 다시 시작해야 할 수 있습니다.\n⌥Tab으로 열고, ⌥를 누른 채 Tab으로 이동한 뒤 놓으면 전환합니다.",
            "Accessibility: ⌥Tab shortcut and individual window switching\nScreen & System Audio Recording: window thumbnails\n\nQuit AltTab or disable its shortcut before using ScreenTap.\nYou may need to restart ScreenTap after changing permissions.\nHold ⌥, press Tab to select, then release ⌥ to switch."))
        description.frame = NSRect(x: 28, y: 142, width: 530, height: 166); root.addSubview(description)
        let state = NSTextField(labelWithString: "\(L.text("접근성", "Accessibility")): \(AXIsProcessTrusted() ? "✓" : "—")    \(L.text("화면 기록", "Screen Recording")): \(CGPreflightScreenCaptureAccess() ? "✓" : "—")")
        state.frame = NSRect(x: 28, y: 110, width: 530, height: 24); root.addSubview(state)
        for (title, action, x) in [
            (L.text("접근성 설정", "Accessibility"), #selector(openAccessibility), CGFloat(28)),
            (L.text("화면 기록 설정", "Screen Recording"), #selector(openScreenRecording), CGFloat(202)),
            (L.text("다시 연결", "Reconnect"), #selector(checkPermissions), CGFloat(400))] {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded; button.frame = NSRect(x: x, y: 42, width: 160, height: 34); root.addSubview(button)
        }
        window.contentView = root; permissionWindow = window
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func openScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    @objc private func checkPermissions() {
        permissionWindow?.close(); permissionWindow = nil
        if AXIsProcessTrusted() { windows.start() }
        _ = hotkey.start()
        if !AXIsProcessTrusted() || !CGPreflightScreenCaptureAccess() { showPermissions() }
    }

    private func memoryReport() -> String {
        let footprint = MemoryDiagnostics.footprint()
        return "ScreenTap 0.2.0\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nPhysical footprint: \(footprint)\nThumbnail bytes: \(thumbnails.cache.bytes) / \(thumbnails.cache.limit)\nThumbnail count: \(thumbnails.cache.count)\nVisible windows: \(records.count)\nAccessibility: \(AXIsProcessTrusted())\nScreen recording: \(CGPreflightScreenCaptureAccess())\nSwitcher open: \(visible)\n\(thumbnails.diagnosticReport)"
    }
    @objc private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(memoryReport(), forType: .string)
    }

    private func showPreview() {
        createPanel(); visible = true
        let titles = ["ScreenTap · Memory budget", "~/projects — zsh", "# engineering", "Weekly calendar"]
        let apps = ["Chrome", "Terminal", "Slack", "Calendar"]
        records = (0..<17).map { index -> WindowRecord in
            let key = WindowKey(pid: getpid(), id: UInt32(index + 1))
            return WindowRecord(key: key, title: titles[index % 4], appName: apps[index % 4],
                minimized: index == 5, hidden: false, element: AXUIElementCreateApplication(getpid()))
        }
        selection.reset(count: records.count, selectPrevious: true)
        let offset = 0
        view?.reset(records: Array(records.prefix(pageSize)), selected: selection.index, offset: offset, total: records.count, columns: columns)
        view?.status = L.text("레이아웃 미리보기 · 실제 창 캡처가 아닙니다", "Layout preview · synthetic data")
        panel?.orderFrontRegardless()
    }

    private func renderPreview() {
        showPreview()
        panel?.orderOut(nil)
        guard let view, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let png = bitmap.representation(using: .png, properties: [:]) {
            let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/layout-preview.png")
            do { try png.write(to: path); print("Rendered: \(path.path)") }
            catch { fputs("Preview export failed: \(error)\n", stderr) }
        }
        print(memoryReport())
        dismiss()
    }
}
