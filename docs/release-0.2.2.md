# ScreenTap 0.2.2

Fixes a 0.2.1 regression where Allow only opened System Settings without making an
OS permission request. That flow could leave ScreenTap absent from the permission list.

- Screen Recording: after the app's Allow confirmation, make one ScreenCaptureKit
  shareable-content request to trigger macOS authorization. Only enumerate metadata;
  no screenshot, audio recording, or continuous capture starts during setup.
- Accessibility: send the native AX permission request after Allow confirmation.
- Deny sends no request and does not open settings.
- The app does not automatically open System Settings after the native request.
  The system dialog controls its own navigation; the app offers a separate
  Open Settings follow-up without repeating the native request.
- Show app in Finder highlights the exact running app bundle for manual + addition
  when needed. Automatic state refresh and Restart app remain available.

Diagnostics now include the OS request result and running app path to distinguish
permission errors from an older installed copy.

The native macOS permission dialog is controlled by the OS and cannot be replaced
by the app's own Allow / Deny dialog.

Quit the previous instance, then run the new ScreenTap.app. A rebuild or a move
may require macOS authorization again. The build is ad-hoc signed.
