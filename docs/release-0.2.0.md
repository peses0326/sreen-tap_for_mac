# ScreenTap 0.2.0

ScreenTap 0.2.0: a native macOS window switcher with a new window-and-arrow icon.

- Recognize individual windows with thumbnail previews and recently used ordering.
- Hold Option and press Tab to choose a window; release Option to switch.
- Click a blank area or press Escape to cancel without changing windows.
- Keep a bounded thumbnail cache and clear it when the switcher closes.
- Korean and English interface.
- Open-source MIT License, copyright © 2026 peses0326.

Rebuilds and installation path changes may require reauthorizing Accessibility and Screen Recording.

## Install

Download `ScreenTap-macOS-arm64.zip`, unzip it, and move `ScreenTap.app` to Applications.
The optional DMG contains the same app and an Applications shortcut.

Requires Apple Silicon and macOS 14 or later. Runtime validation was performed on
macOS 26.6. This personal release is ad-hoc signed, not Developer ID signed or
notarized; macOS may require you to review it in Privacy & Security before opening.
Source and build instructions are included in the repository.

Enable Accessibility and Screen & System Audio Recording for previews and switching.
ScreenTap does not capture audio. Quit any other app using Option-Tab.

Marketing screenshots use the production grid renderer with synthetic demo content;
no private user windows are included. Historical memory samples in the documentation
are from version 0.1.1, not a new benchmark of 0.2.0.
