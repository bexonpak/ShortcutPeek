//
//  Shortcut.swift
//  CheatKey
//
//  Created by Bexon Pak on 15.06.26.
//

import Foundation

/// A modifier key that can appear in a keyboard shortcut.
enum ModifierKey: String, Sendable, CaseIterable, Identifiable {
  case command = "\u{2318}"
  case shift = "\u{21E7}"
  case option = "\u{2325}"
  case control = "\u{2303}"
  case capsLock = "\u{21EA}"
  case globe = "\u{1F310}"

  var id: String { rawValue }

  /// Name of the matching SF Symbol.
  var sfSymbolName: String {
    switch self {
    case .command:  return "command"
    case .shift:    return "shift"
    case .option:   return "option"
    case .control:  return "control"
    case .capsLock: return "capslock"
    case .globe:    return "globe"
    }
  }

}

/// A single keyboard shortcut within a group.
struct ShortcutItem: Identifiable, Sendable, Equatable {
  let id = UUID()
  let modifiers: [ModifierKey]
  let key: String
  let keySymbolName: String?
  let description: String

  init(modifiers: [ModifierKey], key: String, keySymbolName: String? = nil, description: String) {
    self.modifiers = modifiers
    self.key = key
    self.keySymbolName = keySymbolName
    self.description = description
  }
}

/// A category of shortcuts (e.g. "Edit", "File", "Navigation").
struct ShortcutGroup: Identifiable, Sendable, Equatable {
  let id = UUID()
  let category: String
  let items: [ShortcutItem]
}
