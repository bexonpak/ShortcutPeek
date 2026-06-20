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
/// actions.
@MainActor
final class OverlayViewModel {

  // MARK: – Dependency

  private let useCase: OverlayUseCase

  /// Whether the overlay is globally enabled (proxied from the use case).
  var isEnabled: Bool { useCase.isEnabled }

  // MARK: – Init

  init(useCase: OverlayUseCase) {
    self.useCase = useCase
  }

  // MARK: – Actions (delegated to use case)

  func start() { useCase.start() }

  func toggleEnabled() { useCase.toggleEnabled() }

  func showShortcuts() { useCase.showShortcuts() }
}
