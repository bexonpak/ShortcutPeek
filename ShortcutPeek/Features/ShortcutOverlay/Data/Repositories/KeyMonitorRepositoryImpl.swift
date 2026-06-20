//
//  GlobalKeyMonitor.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 15.06.26.
//

import Cocoa
import Combine

/// Monitors keyboard events to detect when the Command key
/// is pressed (and held) vs released.
///
/// Uses **both** a global monitor (events from other apps) and a local
/// monitor (events when ShortcutPeek itself is frontmost) so the overlay
/// works regardless of which app has focus.
///
/// ## Accessibility permission
/// The *global* monitor requires Accessibility access to receive events
/// from other processes.  The *local* monitor always works for ShortcutPeek's
/// own events.
@MainActor
final class KeyMonitorRepositoryImpl: KeyMonitorRepository {

  // MARK: – Output

  /// Emits `true` when the Command key transitions to pressed,
  /// and `false` when it transitions to released.
  let commandKeyPressed = PassthroughSubject<Bool, Never>()

  // MARK: – Private state

  private var globalMonitor: Any?
  private var localMonitor: Any?

  // MARK: – Lifecycle

  nonisolated deinit {
    // Schedule cleanup on the main actor.
    let g = globalMonitor
    let l = localMonitor
    Task { @MainActor in
      if let g { NSEvent.removeMonitor(g) }
      if let l { NSEvent.removeMonitor(l) }
    }
  }

  func start() {
    guard globalMonitor == nil else { return }

    // Local monitor: receives events for ShortcutPeek's own windows.
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) {
      [weak self] event in
      self?.commandKeyPressed.send(event.modifierFlags.contains(.command))
      return event
    }

    // Global monitor: receives events from other processes.
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) {
      [weak self] event in
      self?.commandKeyPressed.send(event.modifierFlags.contains(.command))
    }
  }

  func stop() {
    if let g = globalMonitor {
      NSEvent.removeMonitor(g)
      globalMonitor = nil
    }
    if let l = localMonitor {
      NSEvent.removeMonitor(l)
      localMonitor = nil
    }
  }
}
