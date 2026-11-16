// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import AppKit
import ApplicationServices
import ScreenTapCore
import Darwin

struct WindowRecord {
    let key: WindowKey
    let title: String
    let appName: String
    let minimized: Bool
    let hidden: Bool
    let element: AXUIElement
}

// Exact window IDs are required for multiple same-title windows. This optional private
// symbol is isolated here; if unavailable, use AXWindowNumber or omit unmappable windows.
private enum WindowIdentity {
    typealias Getter = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    static let getter: Getter? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(symbol, to: Getter.self)
    }()
    static func id(_ element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        if let getter, getter(element, &id) == .success, id != 0 { return id }
        return (attribute(element, "AXWindowNumber") as? NSNumber)?.uint32Value
    }
}

private func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
    return value
}

final class WindowService {
    private let queue = DispatchQueue(label: "local.screentap.accessibility", qos: .userInitiated)
    private var observers: [pid_t: AXObserver] = [:]
    private var order = WindowOrder()
    private var tokens: [NSObjectProtocol] = []
    private var isTracking = false

    func start() {
        queue.async { [self] in
            guard !isTracking else { return }
            isTracking = true
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                observe(app.processIdentifier)
            }
            noteFrontmost()
        }
        guard tokens.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let self, let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self.queue.async {
                    guard self.isTracking else { return }
                    if name == NSWorkspace.didTerminateApplicationNotification {
                        if let observer = self.observers.removeValue(forKey: app.processIdentifier) {
                            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
                        }
                    } else {
                        self.observe(app.processIdentifier)
                        if name == NSWorkspace.didActivateApplicationNotification { self.noteFrontmost() }
                    }
                }
            })
        }
    }

    func stop() {
        queue.async { [self] in
            for observer in observers.values {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
            observers.removeAll(); isTracking = false
        }
    }

    private func observe(_ pid: pid_t) {
        guard pid != getpid(), observers[pid] == nil, AXIsProcessTrusted() else { return }
        var result: AXObserver?
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            let service = Unmanaged<WindowService>.fromOpaque(context).takeUnretainedValue()
            service.queue.async { service.noteFrontmost() }
        }
        guard AXObserverCreate(pid, callback, &result) == .success, let observer = result else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXFocusedWindowChangedNotification, kAXWindowCreatedNotification] {
            AXObserverAddNotification(observer, app, name as CFString, context)
        }
        observers[pid] = observer
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func noteFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.15)
        guard let focused = attribute(element, kAXFocusedWindowAttribute) else { return }
        let window = focused as! AXUIElement
        if let id = WindowIdentity.id(window) { order.touch(WindowKey(pid: app.processIdentifier, id: id)) }
    }

    func snapshot(completion: @escaping ([WindowRecord]) -> Void) {
        queue.async { [self] in
            noteFrontmost()
            let zOrder = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
                .compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
            let ranks = Dictionary(zOrder.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: min)
            var records: [WindowRecord] = []
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != getpid() {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(element, 0.15)
                guard let windows = attribute(element, kAXWindowsAttribute) as? [AXUIElement] else { continue }
                for window in windows {
                    guard let id = WindowIdentity.id(window), id != 0,
                          let role = attribute(window, kAXRoleAttribute) as? String, role == kAXWindowRole else { continue }
                    let subrole = attribute(window, kAXSubroleAttribute) as? String
                    guard subrole == kAXStandardWindowSubrole || subrole == kAXDialogSubrole else { continue }
                    records.append(WindowRecord(key: WindowKey(pid: app.processIdentifier, id: id),
                        title: attribute(window, kAXTitleAttribute) as? String ?? "",
                        appName: app.localizedName ?? "App", minimized: attribute(window, kAXMinimizedAttribute) as? Bool ?? false,
                        hidden: app.isHidden, element: window))
                }
            }
            var unique: [WindowKey: WindowRecord] = [:]
            for record in records { unique[record.key] = record }
            records = Array(unique.values).sorted {
                let a = ranks[$0.key.id, default: Int.max], b = ranks[$1.key.id, default: Int.max]
                if a != b { return a < b }
                if $0.key.pid != $1.key.pid { return $0.key.pid < $1.key.pid }
                return $0.key.id < $1.key.id
            }
            order.prune(live: Set(unique.keys))
            let sorted = order.sorted(records.map(\.key)).compactMap { unique[$0] }
            DispatchQueue.main.async { completion(sorted) }
        }
    }

    func focus(_ record: WindowRecord, completion: @escaping (Bool) -> Void) {
        queue.async { [self] in
            guard let app = NSRunningApplication(processIdentifier: record.key.pid) else {
                DispatchQueue.main.async { completion(false) }; return
            }
            AXUIElementSetMessagingTimeout(record.element, 0.25)
            if record.minimized { AXUIElementSetAttributeValue(record.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) }
            app.unhide()
            app.activate(options: [])
            let result = AXUIElementPerformAction(record.element, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(record.element, kAXMainAttribute as CFString, kCFBooleanTrue)
            if result == .success { order.touch(record.key) }
            DispatchQueue.main.async { completion(result == .success) }
        }
    }

    func perform(_ action: String, on record: WindowRecord) {
        queue.async {
            if action == "close", let button = attribute(record.element, kAXCloseButtonAttribute) {
                AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            } else if action == "minimize" {
                AXUIElementSetAttributeValue(record.element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            }
        }
    }
}
