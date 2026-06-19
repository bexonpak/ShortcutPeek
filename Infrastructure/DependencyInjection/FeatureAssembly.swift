//
//  FeatureAssembly.swift
//  CheatKey
//
//  Created by Bexon Pak on 18.06.26.
//

/// Composition root for the ShortcutOverlay feature.
///
/// This is the **only** place where concrete service types are
/// instantiated. Every other layer depends on protocols defined
/// in the Domain layer.
enum FeatureAssembly {

  /// Builds the fully‑wired overlay feature coordinator.
  @MainActor
  static func makeOverlayViewModel() -> OverlayViewModel {
    let keyMonitor = KeyMonitorRepositoryImpl()
    let appTracker = AppTrackerRepositoryImpl()
    let panelController = OverlayPanelRepositoryImpl()

    let useCase = OverlayUseCaseImpl(
      keyMonitor: keyMonitor,
      appTracker: appTracker,
      panelController: panelController
    )

    return OverlayViewModel(useCase: useCase)
  }
}
