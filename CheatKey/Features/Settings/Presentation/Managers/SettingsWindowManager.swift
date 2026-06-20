//
//  SettingsWindowManager.swift
//  CheatKey
//
//  Created by Bexon Pak on 20.06.26.
//

import Cocoa
import SwiftUI

/// Manages the CheatKey settings window lifecycle independently of the
/// shortcut overlay.
@MainActor
final class SettingsWindowManager {

  private var panel: NSWindow?

  func open() {
    if let panel, panel.isVisible {
      panel.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "CheatKey Settings"
    window.level = .floating
    window.isReleasedWhenClosed = false
    window.center()
    window.contentViewController = NSHostingController(rootView: SettingsView())
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    panel = window
  }
}
