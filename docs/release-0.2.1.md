# ScreenTap 0.2.1

Permission setup now uses an app-owned Allow / Deny dialog. Allow is the default
button and opens the relevant System Settings pane once; Deny leaves it closed.
The extra native prompt followed by another settings launch has been removed.

Actual permissions still require the user's approval in macOS. If ScreenTap is
not listed, add it with the + button. ScreenTap does not grant itself access.

While setup is visible, status refreshes every half second. Accessibility approval
connects window tracking and the shortcut without a manual reconnect. Normal
menu-bar operation has no permission polling timer. Disabled event taps can be
recreated, and stale accessibility observers are removed when permission is lost.

If macOS still reports a missing permission after it is enabled, the setup window
offers Restart app. The old process exits only after a new instance is launched.

The repository, release download links and Pages address now point to
`peses0326/sreen-tap_for_mac`.

Install: unzip `ScreenTap-macOS-arm64.zip` and launch `ScreenTap.app`. Quit the
previous running instance first. The build is ad-hoc signed, not Developer ID
signed or notarized. Rebuilds may require confirming permissions again.
