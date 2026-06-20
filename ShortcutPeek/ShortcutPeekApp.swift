//
//  ShortcutPeekApp.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 15.06.26.
//

import SwiftUI

@main
struct ShortcutPeekApp: App {

  /// The feature coordinator that lives for the entire app lifetime.
  @State private var overlayViewModel = FeatureAssembly.makeOverlayViewModel()

  /// The system‑menu‑bar icon and its dropdown.
  @State private var menuBarManager: MenuBarManager?

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onAppear {
          overlayViewModel.start()
          menuBarManager = MenuBarManager(overlayViewModel: overlayViewModel)
        }
    }
    .windowResizability(.contentSize)
  }
}
