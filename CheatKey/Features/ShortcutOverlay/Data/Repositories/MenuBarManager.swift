//
//  MenuBarManager.swift
//  CheatKey
//
//  Created by Bexon Pak on 18.06.26.
//

import Cocoa

/// Manages the CheatKey icon in the system menu bar (top‑right area,
/// alongside Wi‑Fi, battery, input‑method indicators).
///
/// Provides a dropdown menu with:
/// - Toggle overlay on/off
/// - Open settings
/// - Quit
@MainActor
final class MenuBarManager {

  // MARK: – Dependencies

  private let overlayViewModel: OverlayViewModel

  // MARK: – State

  private let statusItem: NSStatusItem

  // MARK: – Lifecycle

  deinit {
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  // MARK: – Init

  init(overlayViewModel: OverlayViewModel) {
    self.overlayViewModel = overlayViewModel

    statusItem = NSStatusBar.system.statusItem(
      withLength: NSStatusItem.squareLength
    )

    statusItem.button?.image = NSImage(systemSymbolName: "command",
                                       accessibilityDescription: "CheatKey")
    statusItem.button?.image?.isTemplate = true

    // Dim the icon when CheatKey is disabled.
    statusItem.button?.alphaValue = overlayViewModel.isEnabled ? 1.0 : 0.5

    statusItem.menu = buildMenu()
  }

  // MARK: – Menu

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()

    let toggleItem = NSMenuItem(
      title: overlayViewModel.isEnabled ? "Disable CheatKey" : "Enable CheatKey",
      action: #selector(toggleEnabled),
      keyEquivalent: ""
    )
    toggleItem.target = self
    menu.addItem(toggleItem)

    menu.addItem(NSMenuItem.separator())

    let settingsItem = NSMenuItem(
      title: "Settings…",
      action: #selector(openSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    menu.addItem(settingsItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: "Quit CheatKey",
      action: #selector(quitApp),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    return menu
  }

  /// Rebuilds the menu and updates the icon opacity to reflect the
  /// current enabled state.
  func updateMenu() {
    statusItem.menu = buildMenu()
    statusItem.button?.alphaValue = overlayViewModel.isEnabled ? 1.0 : 0.4
  }

  // MARK: – Actions

  @objc private func toggleEnabled() {
    overlayViewModel.toggleEnabled()
    updateMenu()
  }

  @objc private func openSettings() {
    overlayViewModel.openSettings()
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }
}
