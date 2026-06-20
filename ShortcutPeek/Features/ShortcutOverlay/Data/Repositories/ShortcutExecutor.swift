//
//  ShortcutExecutor.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 19.06.26.
//

import Carbon
import Cocoa

/// Posts a keyboard shortcut to the frontmost application
/// by synthesizing Core Graphics events.
enum ShortcutExecutor {

  /// Execute the given shortcut, posting key events to the specified
  /// target process (the app whose shortcuts are being displayed).
  static func execute(_ item: ShortcutItem, targetPID: pid_t) {
    guard let keyCode = keyCode(for: item.key) else { return }

    let flags = cgEventFlags(from: item.modifiers)

    guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let keyUp   = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else { return }

    keyDown.flags = flags
    keyUp.flags   = flags

    keyDown.postToPid(targetPID)
    keyUp.postToPid(targetPID)
  }

  // MARK: – Helpers

  private static func cgEventFlags(from modifiers: [ModifierKey]) -> CGEventFlags {
    var flags: CGEventFlags = []
    for m in modifiers {
      switch m {
      case .command:  flags.insert(.maskCommand)
      case .shift:    flags.insert(.maskShift)
      case .option:   flags.insert(.maskAlternate)
      case .control:  flags.insert(.maskControl)
      case .capsLock: flags.insert(.maskAlphaShift)
      case .globe:    flags.insert(.maskSecondaryFn)
      }
    }
    return flags
  }

  // MARK: – Key code mapping

  /// Maps a `ShortcutItem.key` display string to a virtual key code.
  private static func keyCode(for key: String) -> CGKeyCode? {
    switch key {
    // Letters
    case "A": return 0x00
    case "B": return 0x0B
    case "C": return 0x08
    case "D": return 0x02
    case "E": return 0x0E
    case "F": return 0x03
    case "G": return 0x05
    case "H": return 0x04
    case "I": return 0x22
    case "J": return 0x26
    case "K": return 0x28
    case "L": return 0x25
    case "M": return 0x2E
    case "N": return 0x2D
    case "O": return 0x1F
    case "P": return 0x23
    case "Q": return 0x0C
    case "R": return 0x0F
    case "S": return 0x01
    case "T": return 0x11
    case "U": return 0x20
    case "V": return 0x09
    case "W": return 0x0D
    case "X": return 0x07
    case "Y": return 0x10
    case "Z": return 0x06

    // Digits
    case "0": return 0x1D
    case "1": return 0x12
    case "2": return 0x13
    case "3": return 0x14
    case "4": return 0x15
    case "5": return 0x17
    case "6": return 0x16
    case "7": return 0x1A
    case "8": return 0x1C
    case "9": return 0x19

    // Display symbols from mapKey
    case "Space": return 0x31
    case "↵":     return 0x24  // Return
    case "⌫":     return 0x33  // Backspace / Delete
    case "⌦":     return 0x2F  // Forward Delete (period on US layout → Fwd Del)
    case "⎋":     return 0x35  // Escape
    case "⇥":     return 0x30  // Tab
    case "⌧":     return 0x47  // Clear
    case "⇱":     return 0x73  // Home
    case "⇲":     return 0x77  // End
    case "⇞":     return 0x74  // Page Up
    case "⇟":     return 0x79  // Page Down
    case "←":     return 0x7B
    case "→":     return 0x7C
    case "↑":     return 0x7E
    case "↓":     return 0x7D

    // Punctuation
    case ".":  return 0x2F
    case ",":  return 0x2B
    case "/":  return 0x2C
    case ";":  return 0x29
    case "'":  return 0x27
    case "[":  return 0x21
    case "]":  return 0x1E
    case "\\": return 0x2A
    case "-":  return 0x1B
    case "=":  return 0x18
    case "`":  return 0x32

    // Function keys
    case "F1":  return 0x7A
    case "F2":  return 0x78
    case "F3":  return 0x63
    case "F4":  return 0x76
    case "F5":  return 0x60
    case "F6":  return 0x61
    case "F7":  return 0x62
    case "F8":  return 0x64
    case "F9":  return 0x65
    case "F10": return 0x6D
    case "F11": return 0x67
    case "F12": return 0x6F

    default: return nil
    }
  }
}
