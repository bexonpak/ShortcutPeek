//
//  DefaultOverlayUseCase.swift
//  CheatKey
//
//  Created by Bexon Pak on 18.06.26.
//

import Combine
import Foundation

/// Implements all overlay business logic:
/// - Command‑key hold threshold
/// - Enabled‑state management (persisted to UserDefaults)
/// - Show / hide / refresh decision
/// - App‑switch handling while overlay is visible
///
/// Depends only on Domain protocols — no concrete services.
@MainActor
final class OverlayUseCaseImpl: OverlayUseCase {

  // MARK: – Dependencies (Domain protocols)

  private let keyMonitor: KeyMonitorRepository
  private let appTracker: AppTrackerRepository
  private let panelController: OverlayPanelRepository

  // MARK: – State

  private var cancellables = Set<AnyCancellable>()
  private var holdTask: Task<Void, Never>?
  private var readTask: Task<Void, Never>?
  private var isOverlayVisible = false
  private var isStarted = false

  /// Cache the last successful shortcut read so we don't repeat AX reads
  /// when the frontmost app hasn't changed.
  private var lastAppPID: pid_t?
  private var cachedGroups: [ShortcutGroup]?
  private var cachedAppName: String?
  private var cachedAppIconData: Data?

  private(set) var isEnabled = true {
    didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
  }

  // MARK: – Init

  init(
    keyMonitor: KeyMonitorRepository,
    appTracker: AppTrackerRepository,
    panelController: OverlayPanelRepository
  ) {
    self.keyMonitor = keyMonitor
    self.appTracker = appTracker
    self.panelController = panelController
    isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
  }

  // MARK: – Start / Stop

  func start() {
    guard !isStarted else { return }
    isStarted = true

    keyMonitor.commandKeyPressed
      .removeDuplicates()
      .sink { [weak self] isPressed in
        guard let self else { return }
        if isPressed { onCommandDown() }
        else { onCommandUp() }
      }
      .store(in: &cancellables)

    keyMonitor.start()

    appTracker.activeAppChanged
      .sink { [weak self] _ in
        guard let self, isOverlayVisible else { return }
        // App changed — invalidate cached shortcuts so we re-read.
        lastAppPID = nil
        cachedGroups = nil
        refreshOverlay()
      }
      .store(in: &cancellables)

    appTracker.start()
  }

  func stop() {
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
    holdTask?.cancel()
    holdTask = nil
    readTask?.cancel()
    readTask = nil
    keyMonitor.stop()
    panelController.hide()
    isOverlayVisible = false
    isStarted = false
    lastAppPID = nil
    cachedGroups = nil
    cachedAppName = nil
    cachedAppIconData = nil
  }

  func toggleEnabled() {
    isEnabled.toggle()
    if !isEnabled { hideOverlay() }
  }

  // MARK: – Hold-timer logic

  private static let holdTagKey = "holdDurationTag"
  private static let enabledKey = "overlayEnabled"

  private var holdDurationNanos: UInt64 {
    let tag = UserDefaults.standard.integer(forKey: Self.holdTagKey)
    switch tag {
    case 0:  return 700_000_000
    case 2:  return 2_000_000_000
    default: return 1_000_000_000
    }
  }

  private func onCommandDown() {
    guard isEnabled else { return }
    holdTask?.cancel()

    holdTask = Task { [weak self] in
      guard let self else { return }
      do { try await Task.sleep(nanoseconds: holdDurationNanos) }
      catch { return }
      guard !Task.isCancelled else { return }
      showOverlay()
    }
  }

  private func onCommandUp() {
    holdTask?.cancel()
    holdTask = nil
    hideOverlay()
  }

  // MARK: – Overlay show / hide

  private func showOverlay() {
    isOverlayVisible = true
    refreshOverlay()
  }

  private func hideOverlay() {
    isOverlayVisible = false
    readTask?.cancel()
    readTask = nil
    panelController.hide()
  }

  private func refreshOverlay() {
    guard let app = ActiveApp.current() else { return }
    readTask?.cancel()

    // If the frontmost app hasn't changed since the last successful
    // read, reuse the cached result — avoids a full AX menu traversal
    // and TIFF encode/decode cycle.
    if app.pid == lastAppPID, let groups = cachedGroups {
      panelController.show(
        shortcuts: groups,
        appName: cachedAppName ?? app.name,
        appIconData: cachedAppIconData ?? app.icon,
        targetPID: app.pid
      )
      return
    }

    if AccessibilityService.isTrusted {
      let groups = MenuBarShortcutReader.readShortcuts(forPID: app.pid)
      if !groups.isEmpty {
        lastAppPID = app.pid
        cachedGroups = groups
        cachedAppName = app.name
        cachedAppIconData = app.icon
        panelController.show(
          shortcuts: groups,
          appName: app.name,
          appIconData: app.icon,
          targetPID: app.pid
        )
        return
      }
    }

    panelController.hide()
  }
}
