// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326
import Foundation

enum L {
    static var language: String { UserDefaults.standard.string(forKey: "language") ?? "auto" }
    static var korean: Bool {
        language == "ko" || (language == "auto" && Locale.preferredLanguages.first?.hasPrefix("ko") == true)
    }
    static func text(_ ko: String, _ en: String) -> String { korean ? ko : en }
}
