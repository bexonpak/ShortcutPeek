//
//  ActiveAppTracking.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 18.06.26.
//

import Combine

/// Abstracts frontmost‑application tracking so UseCases do not
/// depend on the concrete `AppTrackerRepositoryImpl` implementation.
protocol AppTrackerRepository: AnyObject {
  var activeAppChanged: PassthroughSubject<Void, Never> { get }
  func start()
}
