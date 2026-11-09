// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import AppKit

if CommandLine.arguments.contains("--diagnostics") {
    print("ScreenTap headless process footprint: \(MemoryDiagnostics.footprint())")
    print("Excludes GUI and capture. Use menu diagnostics to measure real usage.")
} else {
    let app = NSApplication.shared
    let controller = AppController()
    app.delegate = controller
    withExtendedLifetime(controller) { app.run() }
}
