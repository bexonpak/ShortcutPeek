//
//  AccessibilityService.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 15.06.26.
//

import ApplicationServices
import Cocoa

/// Checks whether the current process has been granted Accessibility
/// permissions, and can prompt the user to grant them.
enum AccessibilityService {

  /// `true` once the user has granted accessibility access to this app.
  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  /// Requests accessibility permission via the system dialog.
  ///
  /// macOS will present a modal alert asking the user to authorise this app
  /// in **System Settings → Privacy & Security → Accessibility**.
  /// The call is intentionally made on a background queue because certain
  /// system APIs (event taps) may block while waiting for user input.
  static func requestPermission() {
    DispatchQueue.global(qos: .userInitiated).async {
      // 1. Try the AX trusted-check prompt (system dialog).
      systemTrustedCheckPrompt()

      // 2. Also attempt to create a CGEvent tap; if the app isn't trusted
      //    the system shows the same permission dialog as a side effect.
      triggerEventTapPrompt()

      // 3. Open the exact settings pane as a visible fallback.
      DispatchQueue.main.async {
        openAccessibilitySettings()
      }
    }
  }

  /// Calls `AXIsProcessTrustedWithOptions` with the prompt flag.
  private static func systemTrustedCheckPrompt() {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [key: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  /// Attempts to create an `CGEvent` tap.  When the app is *not* trusted,
  /// the system intercepts this call and presents the accessibility
  /// permission dialog automatically.
  private static func triggerEventTapPrompt() {
    let eventMask = CGEventMask(
      (1 << CGEventType.flagsChanged.rawValue) |
      (1 << CGEventType.keyDown.rawValue)
    )

    // Creating (and immediately discarding) a tap is enough to trigger
    // the system accessibility prompt when the app isn't trusted yet.
    _ = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: eventMask,
      callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
      userInfo: nil
    )
  }

  /// Opens the Accessibility privacy pane in System Settings (macOS 13+).
  private static func openAccessibilitySettings() {
    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    if let url = url {
      NSWorkspace.shared.open(url)
    }
  }
}
