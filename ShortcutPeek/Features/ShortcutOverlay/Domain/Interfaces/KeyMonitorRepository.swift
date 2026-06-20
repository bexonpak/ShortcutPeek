//
//  GlobalKeyMonitoring.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 18.06.26.
//

import Combine

/// Abstracts keyboard event monitoring so UseCases do not depend
/// on the concrete `KeyMonitorRepositoryImpl` implementation.
protocol KeyMonitorRepository: AnyObject {
  var commandKeyPressed: PassthroughSubject<Bool, Never> { get }
  func start()
  func stop()
}
