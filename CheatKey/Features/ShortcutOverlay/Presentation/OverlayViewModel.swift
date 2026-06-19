//
//  OverlayViewModel.swift
//  CheatKey
//
//  Created by Bexon Pak on 15.06.26.
//

import SwiftUI

/// Presentation‑layer bridge between SwiftUI views and the
/// shortcut‑overlay use case.
///
/// All business logic lives in `OverlayUseCase`; this ViewModel is
/// responsible only for translating use‑case state into UI‑ready
/// actions and managing the settings window.
@MainActor
final class OverlayViewModel {

  // MARK: – Dependency

  private let useCase: OverlayUseCase

  // MARK: – Presentation state

  private var settingsPanel: NSWindow?

  /// Whether the overlay is globally enabled (proxied from the use case).
  var isEnabled: Bool { useCase.isEnabled }

  // MARK: – Init

  init(useCase: OverlayUseCase) {
    self.useCase = useCase
  }

  // MARK: – Actions (delegated to use case)

  func start() { useCase.start() }

  func toggleEnabled() { useCase.toggleEnabled() }

  // MARK: – Settings window (presentation concern)

  func openSettings() {
    if let panel = settingsPanel, panel.isVisible {
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
    window.isReleasedWhenClosed = false
    window.level = .floating
    window.center()
    window.contentViewController = NSHostingController(rootView: SettingsView())
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification,
      object: window,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        self.settingsPanel = nil
      }
    }

    settingsPanel = window
  }
}
