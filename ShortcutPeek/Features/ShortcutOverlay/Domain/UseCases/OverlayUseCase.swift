//
//  OverlayUseCase.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 18.06.26.
//

/// Orchestrates the overlay feature's business logic without coupling
/// to concrete services or presentation frameworks.
///
/// Presentation layer depends on this protocol, not on the concrete
/// `OverlayUseCaseImpl`.
protocol OverlayUseCase: AnyObject {
  var isEnabled: Bool { get }
  func start()
  func stop()
  func toggleEnabled()
  func showShortcuts()
}
