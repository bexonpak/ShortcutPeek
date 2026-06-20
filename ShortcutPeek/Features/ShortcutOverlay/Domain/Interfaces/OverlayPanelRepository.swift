//
//  OverlayPanelControlling.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 18.06.26.
//

import Foundation

/// Abstracts the floating panel lifecycle so UseCases do not depend
/// on the concrete `OverlayPanelRepositoryImpl` implementation.
protocol OverlayPanelRepository: AnyObject {
  func show(shortcuts: [ShortcutGroup], appName: String, appIconData: Data?, targetPID: pid_t, showsCloseButton: Bool)
  func hide()
}
