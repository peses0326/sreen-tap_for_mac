// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import AppKit
import ApplicationServices
import ScreenCaptureKit
import ScreenTapCore

struct PermissionStatus: Equatable {
    let accessibility: Bool
    let screenRecording: Bool
    let shortcut: Bool
    var isReady: Bool { accessibility && screenRecording && shortcut }
}

final class PermissionsController: NSWindowController, NSWindowDelegate {
    var readStatus: (() -> PermissionStatus)?
    var restart: (() -> Void)?
    private var monitor: Timer?
    private var presentingConsent = false
    private var lastShownStatus: PermissionStatus?
    private var screenRequestOutcome = "not requested"
    var diagnosticReport: String {
        "Accessibility OS request sent: \(requests.hasRequested(.accessibility))\nScreen Recording OS request sent: \(requests.hasRequested(.screenRecording))\nScreen Recording request result: \(screenRequestOutcome)\n"
    }
    private lazy var requests = PermissionRequests(
        requestSystem: { [weak self] in self?.requestSystemPermission($0) },
        openSettings: { [weak self] in self?.openSystemSettings($0) })
    private let accessibilityState = NSTextField(labelWithString: "")
    private let recordingState = NSTextField(labelWithString: "")
    private let accessibilityButton = NSButton()
    private let recordingButton = NSButton()
    private let message = NSTextField(wrappingLabelWithString: "")
    private let restartButton = NSButton()
    private let closeButton = NSButton()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "ScreenTap"; window.isReleasedWhenClosed = false; window.delegate = self
        window.center(); buildContent()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func present() {
        refresh()
        showWindow(nil); NSApp.activate(ignoringOtherApps: true)
        startMonitoring()
    }
    func refresh(force: Bool = false) {
        guard let status = readStatus?(), force || status != lastShownStatus else { return }
        lastShownStatus = status
        accessibilityState.stringValue = status.accessibility
            ? (status.shortcut ? L.text("허용됨 · 단축키 연결 완료", "Allowed · shortcut connected") : L.text("허용됨 · 단축키 연결 대기", "Allowed · reconnecting shortcut"))
            : L.text("허용 대기", "Awaiting permission")
        recordingState.stringValue = status.screenRecording ? L.text("허용됨", "Allowed") : L.text("허용 대기", "Awaiting permission")
        accessibilityState.textColor = status.accessibility ? .systemGreen : .secondaryLabelColor
        recordingState.textColor = status.screenRecording ? .systemGreen : .secondaryLabelColor
        accessibilityButton.isEnabled = !status.accessibility
        recordingButton.isEnabled = !status.screenRecording
        accessibilityButton.title = status.accessibility ? L.text("허용됨", "Allowed")
            : (requests.hasRequested(.accessibility) ? L.text("설정 열기", "Open Settings") : L.text("허용", "Allow"))
        recordingButton.title = status.screenRecording ? L.text("허용됨", "Allowed")
            : (requests.hasRequested(.screenRecording) ? L.text("설정 열기", "Open Settings") : L.text("허용", "Allow"))
        restartButton.isHidden = status.isReady
        closeButton.title = status.isReady ? L.text("완료", "Done") : L.text("나중에", "Not now")
        message.stringValue = status.isReady
            ? L.text("설정이 완료됐습니다. ⌥Tab으로 창을 전환하세요.", "You're ready. Use ⌥Tab to switch windows.")
            : L.text("설정에서 ScreenTap을 켜면 상태를 자동으로 확인합니다. 이미 켰는데도 대기 중이면 앱을 재시작해 주세요. macOS가 새 실행에서 권한을 반영해야 할 수 있습니다.", "Status updates automatically when you enable ScreenTap in System Settings. If it still says awaiting permission, restart the app. macOS may need a new process to apply the change.")
    }
    func windowDidBecomeKey(_ notification: Notification) { refresh() }
    func windowWillClose(_ notification: Notification) { stopMonitoring() }

    private func startMonitoring() {
        guard monitor == nil else { return }
        // Poll only during visible setup. Normal menu-bar operation has no timer.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.window?.isVisible == true else { self.stopMonitoring(); return }
            self.refresh()
        }
        monitor = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func stopMonitoring() { monitor?.invalidate(); monitor = nil }
    deinit { monitor?.invalidate() }

    private func buildContent() {
        guard let root = window?.contentView else { return }
        let title = NSTextField(labelWithString: L.text("창 전환을 위한 권한 설정", "Permissions for window switching"))
        title.font = .boldSystemFont(ofSize: 23)
        title.frame = NSRect(x: 28, y: 366, width: 565, height: 34); root.addSubview(title)
        let intro = NSTextField(wrappingLabelWithString: L.text("허용을 누르면 macOS에 권한을 요청합니다. 시스템 승인창에서 계속 진행해 주세요.", "Allow sends a permission request to macOS. Continue in the system approval dialog."))
        intro.textColor = .secondaryLabelColor
        intro.frame = NSRect(x: 28, y: 320, width: 565, height: 40); root.addSubview(intro)
        addRow(root, title: L.text("접근성", "Accessibility"), detail: L.text("⌥Tab 단축키와 개별 창 전환", "⌥Tab shortcut and individual window switching"),
               state: accessibilityState, button: accessibilityButton, action: #selector(requestAccessibility), y: 228)
        addRow(root, title: L.text("화면 기록", "Screen Recording"), detail: L.text("창 미리보기 이미지 · 오디오는 캡처하지 않음", "Window thumbnails · no audio is captured"),
               state: recordingState, button: recordingButton, action: #selector(requestRecording), y: 142)
        message.font = .systemFont(ofSize: 11); message.textColor = .secondaryLabelColor
        message.frame = NSRect(x: 28, y: 75, width: 565, height: 56); root.addSubview(message)
        configure(closeButton, title: L.text("나중에", "Not now"), action: #selector(closeSetup), rect: NSRect(x: 28, y: 24, width: 100, height: 32), root: root)
        let location = NSButton()
        configure(location, title: L.text("앱 위치 보기", "Show app in Finder"), action: #selector(showAppLocation), rect: NSRect(x: 142, y: 24, width: 168, height: 32), root: root)
        let refresh = NSButton()
        configure(refresh, title: L.text("다시 확인", "Check again"), action: #selector(checkAgain), rect: NSRect(x: 328, y: 24, width: 118, height: 32), root: root)
        configure(restartButton, title: L.text("앱 재시작", "Restart app"), action: #selector(restartApp), rect: NSRect(x: 456, y: 24, width: 135, height: 32), root: root)
    }
    private func addRow(_ root: NSView, title: String, detail: String, state: NSTextField, button: NSButton, action: Selector, y: CGFloat) {
        let name = NSTextField(labelWithString: title); name.font = .boldSystemFont(ofSize: 15)
        name.frame = NSRect(x: 28, y: y + 45, width: 410, height: 22); root.addSubview(name)
        let subtitle = NSTextField(labelWithString: detail); subtitle.font = .systemFont(ofSize: 11); subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 28, y: y + 23, width: 430, height: 20); root.addSubview(subtitle)
        state.font = .systemFont(ofSize: 11); state.frame = NSRect(x: 28, y: y + 2, width: 430, height: 20); root.addSubview(state)
        configure(button, title: L.text("허용", "Allow"), action: action, rect: NSRect(x: 468, y: y + 19, width: 120, height: 34), root: root)
    }
    private func configure(_ button: NSButton, title: String, action: Selector, rect: NSRect, root: NSView) {
        button.title = title; button.target = self; button.action = action; button.bezelStyle = .rounded
        button.frame = rect; root.addSubview(button)
    }
    @objc private func requestAccessibility() { request(.accessibility) }
    @objc private func requestRecording() { request(.screenRecording) }
    @objc private func checkAgain() { refresh() }
    @objc private func closeSetup() { close() }
    @objc private func restartApp() { restart?() }
    @objc private func showAppLocation() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }

    private func request(_ kind: PermissionKind) {
        guard !presentingConsent, let window, let status = readStatus?() else { return }
        guard kind == .accessibility ? !status.accessibility : !status.screenRecording else { refresh(); return }
        if requests.hasRequested(kind) {
            requests.respond(to: kind, allowed: true); return
        }
        presentingConsent = true
        let name = kind == .accessibility ? L.text("접근성", "Accessibility") : L.text("화면 기록", "Screen Recording")
        let alert = NSAlert()
        alert.messageText = L.text("\(name)을 허용할까요?", "Allow \(name)?")
        alert.informativeText = L.text("허용을 누르면 macOS에 실제 권한 요청을 보냅니다. 시스템 승인창에서 허용하거나 설정 열기를 선택해 주세요. 거부를 누르면 요청하지 않습니다.", "Allow sends a real permission request to macOS. Approve it or choose Open Settings in the system dialog. Deny sends no request.")
        let allow = alert.addButton(withTitle: L.text("허용", "Allow"))
        allow.keyEquivalent = "\r"; allow.bezelColor = .systemBlue
        alert.addButton(withTitle: L.text("거부", "Deny")).keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.presentingConsent = false
            self.requests.respond(to: kind, allowed: response == .alertFirstButtonReturn)
            self.refresh(force: true)
        }
    }

    private func requestSystemPermission(_ kind: PermissionKind) {
        switch kind {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .screenRecording:
            // Use the capture API's authorization path, even when preflight is false.
            // Only enumerate metadata; no screenshot, audio, or stream is captured here.
            screenRequestOutcome = "pending SCShareableContent authorization"
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { [weak self] content, error in
                let outcome: String
                if let error = error as NSError? { outcome = "\(error.domain) (\(error.code)): \(error.localizedDescription)" }
                else { outcome = content == nil ? "no content and no OS error" : "shareable-content enumeration succeeded" }
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.screenRequestOutcome = outcome
                    self.refresh(force: true)
                    if self.readStatus?().screenRecording != true {
                        self.message.stringValue = L.text("macOS에 화면 기록 권한을 요청했습니다. ‘설정 열기’에서 ScreenTap을 켜 주세요. 이미 켰다면 ‘앱 재시작’을 선택하세요.", "Screen Recording permission was requested from macOS. Enable ScreenTap with Open Settings. If already enabled, choose Restart app.")
                    }
                }
            }
        }
    }

    private func openSystemSettings(_ kind: PermissionKind) {
        let pane = kind == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
        // Settings opens only on a separate, explicit follow-up click.
        if !NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!) {
            message.stringValue = L.text("설정 화면을 열지 못했습니다. 시스템 설정의 개인정보 보호 및 보안에서 허용해 주세요.", "Could not open settings. Allow ScreenTap in System Settings → Privacy & Security.")
        }
    }
}
