# ScreenTap 0.2.3

Instant switcher previews and a cleaned-up app identity.

- **Thumbnails appear immediately.** Closing the switcher no longer discards the
  thumbnail cache. Reopening draws the cached previews right away and refreshes
  them in the background, capturing windows without a preview first. Previews of
  closed windows are dropped. The cache stays within its 12MiB limit and is still
  cleared on memory pressure or when Screen Recording is revoked.
- **New bundle identifier:** `local.espark.screentap`. macOS treats this as a new
  app, so Accessibility and Screen Recording must be allowed again after updating.
  Remove any older ScreenTap entries from those lists in System Settings.
- About panel, README, NOTICE and landing page text updated. ScreenTap is written
  independently with Apple frameworks and includes no third-party code or assets.

The first open after launch still captures previews one by one because the cache
starts empty.

## Install

Quit the running ScreenTap, then download `ScreenTap-macOS-arm64.zip`, unzip it, and
move `ScreenTap.app` to Applications. The optional DMG contains the same app.

Requires Apple Silicon and macOS 14 or later. This personal release is ad-hoc signed,
not Developer ID signed or notarized; macOS may require you to review it in
Privacy & Security before opening. ScreenTap does not capture audio.
