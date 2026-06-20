//
//  OverlayPanelController.swift
//  CheatKey
//
//  Created by Bexon Pak on 15.06.26.
//

import Cocoa
import SwiftUI

/// Manages the life‑cycle of the floating overlay window that displays
/// keyboard shortcuts for the currently focused application.
///
/// The window is a non‑activating, borderless `NSPanel` that floats above
/// all other content and does not steal keyboard focus.
@MainActor
final class OverlayPanelRepositoryImpl: OverlayPanelRepository {

  // MARK: – Configuration

  private let panelWidth: CGFloat = 680
  private let panelMaxHeight: CGFloat = 800

  // MARK: – State

  private var panel: NSPanel?
  private var hostingController: NSHostingController<OverlayView>?
  /// Cache decoded app icons keyed by PID to avoid repeated TIFF decoding.
  private var iconImageCache: [pid_t: Image] = [:]

  // MARK: – Show / Hide

  /// Shows the overlay near the center of the screen that currently
  /// contains the mouse pointer.
  func show(shortcuts: [ShortcutGroup], appName: String, appIconData: Data?, targetPID: pid_t, showsCloseButton: Bool = false) {
    let panel = existingPanel ?? makePanel()
    self.panel = panel

    // Build the SwiftUI root view.
    let image: Image? = {
      if let cached = iconImageCache[targetPID] { return cached }
      guard let data = appIconData,
            let nsImage = NSImage(data: data)
      else { return nil }
      let img = Image(nsImage: nsImage)
      iconImageCache[targetPID] = img
      return img
    }()
    let onHide: @Sendable () -> Void = { [weak self] in
      guard let self else { return }
      Task { @MainActor in self.hide() }
    }
    let onClose: @Sendable () -> Void = { [weak self] in
      guard let self else { return }
      Task { @MainActor in self.hide() }
    }
    let viewModel = OverlayPanelViewModel(
      shortcutGroups: shortcuts,
      appName: appName,
      appIcon: image,
      targetPID: targetPID,
      onShortcutExecuted: onHide,
      showsCloseButton: showsCloseButton,
      onClose: showsCloseButton ? onClose : nil
    )
    let overlay = OverlayView(viewModel: viewModel)
    let host = NSHostingController(rootView: overlay)
    panel.contentViewController = host
    hostingController = host

    // Force the hosting view to lay out so fittingSize is accurate.
    host.view.setFrameSize(NSSize(width: panelWidth, height: 0))
    host.view.layoutSubtreeIfNeeded()

    let fittingSize = host.view.fittingSize
    let panelHeight = max(min(fittingSize.height + 20, panelMaxHeight), 200)
    panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))

    // Position in the centre of the screen under the cursor.
    if let screen = locateScreenWithCursor() {
      let centerX = screen.frame.midX - panelWidth / 2
      let centerY = screen.frame.midY - panelHeight / 2 + 60
      panel.setFrameOrigin(NSPoint(x: centerX, y: centerY))
    }

    panel.orderFrontRegardless()
  }

  func hide() {
    panel?.orderOut(nil)
    // Release the entire panel, its view hierarchy, and decoded icon
    // images so memory can be reclaimed.  A fresh panel is cheap to
    // create on the next show.
    hostingController = nil
    panel?.contentViewController = nil
    panel = nil
    iconImageCache.removeAll()
  }

  // MARK: – Helpers

  private var existingPanel: NSPanel? {
    panel?.isVisible == true ? panel : nil
  }

  private func makePanel() -> NSPanel {
    let p = NSPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    p.isFloatingPanel = true
    p.level = .statusBar
    p.isOpaque = false
    p.backgroundColor = .clear
    p.hasShadow = true
    p.isMovable = false
    p.ignoresMouseEvents = false
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    p.hidesOnDeactivate = false
    return p
  }

  /// Returns the `NSScreen` containing the mouse pointer.
  private func locateScreenWithCursor() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { screen in
      screen.frame.contains(mouseLocation)
    } ?? NSScreen.main
  }
}
