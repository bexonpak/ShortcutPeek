//
//  ActiveAppTracker.swift
//  CheatKey
//
//  Created by Bexon Pak on 15.06.26.
//

import Cocoa
import Combine

/// Information about the currently focused application.
struct ActiveApp: Sendable, Equatable {
  let pid: pid_t
  let bundleID: String
  let name: String
  let icon: Data?

  static func current() -> ActiveApp? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    return ActiveApp(
      pid: app.processIdentifier,
      bundleID: (app.bundleIdentifier ?? "unknown").lowercased().trimmingCharacters(in: .whitespaces),
      name: app.localizedName ?? "Unknown",
      icon: app.icon?.tiffRepresentation
    )
  }
}

/// Monitors the frontmost (active) application via `NSWorkspace` notifications.
///
/// Runs on `@MainActor` because it touches Cocoa UI objects (`NSWorkspace`),
/// but reads the frontmost app into a `Sendable` value type.
@MainActor
final class AppTrackerRepositoryImpl: AppTrackerRepository {

  /// Emits the new active app every time the user switches focus.
  let activeAppChanged = PassthroughSubject<Void, Never>()

  private var observer: NSObjectProtocol?

  deinit {
    if let obs = observer { NotificationCenter.default.removeObserver(obs) }
  }

  func start() {
    guard observer == nil else { return }

    // The closure below runs on `.main` (we pass `queue: .main`) so it is
    // safe to use MainActor.assumeIsolated to satisfy @Sendable checking.
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.activeAppChanged.send(())
      }
    }

    // Emit immediately so the UI is populated on first launch.
    activeAppChanged.send(())
  }
}
