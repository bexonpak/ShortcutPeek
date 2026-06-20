//
//  MenuBarShortcutReader.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 15.06.26.
//

import Cocoa
import ApplicationServices

/// Reads keyboard shortcuts from an application's menu bar.
///
/// Two strategies (tried in order):
/// 1. **Accessibility API** — reads any app's menu bar via AX.
/// 2. **NSMenu** — reads ShortcutPeek's own menu (no AX needed).
enum MenuBarShortcutReader {

  // MARK: – Public API

  /// Returns keyboard shortcuts grouped by menu‑bar category (File, Edit, …).
  static func readShortcuts(forPID pid: pid_t) -> [ShortcutGroup] {
    // Strategy 1: Accessibility API.
    if let groups = readViaAX(pid: pid) { return groups }

    // Strategy 2: NSMenu (our own app).
    if pid == ProcessInfo.processInfo.processIdentifier {
      return readOwnNSMenu()
    }

    return []
  }

  // MARK: – Accessibility API

  private static func readViaAX(pid: pid_t) -> [ShortcutGroup]? {
    return autoreleasepool {
      let appElement = AXUIElementCreateApplication(pid)

      // AXMenuBar attribute works even when other AX attributes don't.
      guard let menuBar = axCopyAttribute(element: appElement, attribute: "AXMenuBar") else { return nil }
      let children = axCopyAttributeArray(element: menuBar)
      guard !children.isEmpty else { return nil }

      var groups: [ShortcutGroup] = []

      // First child is the Apple menu () — skip it.
      for menuItem in children.dropFirst() {
        guard let title = axCopyAttributeString(element: menuItem, attribute: "AXTitle"),
              !title.isEmpty
        else { continue }

        let items = axReadMenuItems(from: menuItem)
        guard !items.isEmpty else { continue }
        groups.append(.init(category: title, items: items))
      }

      return groups
    }
  }

  private static func axReadMenuItems(from menuElement: AXUIElement) -> [ShortcutItem] {
    autoreleasepool {
      let children = axCopyAttributeArray(element: menuElement)
      var result: [ShortcutItem] = []

      for child in children {
        guard let role = axCopyAttributeString(element: child, attribute: "AXRole") else { continue }
        switch role {
        case "AXMenuItem":
          if let item = axExtractShortcut(from: child) { result.append(item) }
        case "AXMenu":
          result.append(contentsOf: axReadMenuItems(from: child))
        default: break
        }
      }
      return result
    }
  }

  private static func axExtractShortcut(from element: AXUIElement) -> ShortcutItem? {
    autoreleasepool {
      guard let title = axCopyAttributeString(element: element, attribute: "AXTitle"),
            !title.isEmpty
      else { return nil }

      // Skip submenus (children contain AXMenu).
      let children = axCopyAttributeArray(element: element)
      if children.contains(where: { axCopyAttributeString(element: $0, attribute: "AXRole") == "AXMenu" }) {
        return nil
      }

      let keyChar = axCopyAttributeString(element: element, attribute: "AXMenuItemCmdChar") ?? ""
      guard !keyChar.isEmpty else { return nil }

    // Decode modifiers.  Priority order:
    //   1. Numeric AXMenuItemCmdModifiers (decoded via modifiersFromAXInt)
    //   2. String-form AXMenuItemCmdModifiers ("cmd shift", etc.)
    //   3. Character heuristic (uppercase → shift, non‑ASCII → option)
    //
    // Numeric encoding (reverse‑engineered on macOS 27):
    //   0x0 = ⌘        0x1 = ⇧⌘       0x2 = ⌥⌘       0x3 = ⌥⇧⌘
    //   0x4 = ⌃⌘       0x5 = ⌃⇧⌘      0x6 = ⌃⌥⌘      0x7 = ⌃⌥⇧⌘
    //   0x8 = (none)   0x9 = ⇧        0xa = ⌥        0xb = ⌥⇧
    //   0xc = ⌃        0xd = ⌃⇧       0xe = ⌃⌥       0xf = ⌃⌥⇧
    //   0x18 = 🌐      0x1c = ⌃🌐
    //   Fn keys: \u{F704}–\u{F70F} → F1–F12
    var modifiers: [ModifierKey] = []

    if let modValue = axCopyAttributeInt(element: element, attribute: "AXMenuItemCmdModifiers") {
      modifiers = modifiersFromAXInt(modValue)
    } else if let modStr = axCopyAttributeString(element: element, attribute: "AXMenuItemCmdModifiers"),
              !modStr.isEmpty {
      modifiers = parseAXModifiersString(modStr)
    } else {
      // Last‑resort heuristic.
      modifiers = [.command]
      let isUppercase = keyChar.unicodeScalars.first.map { CharacterSet.uppercaseLetters.contains($0) } ?? false
      let isNonASCII  = keyChar.unicodeScalars.first.map { $0.value > 127 } ?? false
      if isUppercase { modifiers.append(.shift) }
      if isNonASCII  { modifiers.append(.option) }
    }

    let cleanTitle = title
      .replacingOccurrences(of: "…", with: "")
      .trimmingCharacters(in: .whitespaces)

    let mapped = mapKey(keyChar)
    return .init(modifiers: modifiers, key: mapped.text, keySymbolName: mapped.sfSymbol, description: cleanTitle)
    }
  }

  // MARK: – Modifier decoding

  /// Reads an AX attribute as a signed integer.
  private static func axCopyAttributeInt(element: AXUIElement, attribute: String) -> Int? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let num = value as? NSNumber
    else { return nil }
    return num.intValue
  }

  /// Decodes the numeric AXMenuItemCmdModifiers value into modifier keys.
  ///
  /// Bit encoding (bits 0–4):
  ///   bit 0 = shift, bit 1 = option, bit 2 = control
  ///   bit 3 = 0 → include command, bit 3 = 1 → exclude command
  ///   0x18 / 0x1c = globe / control+globe
  private static func modifiersFromAXInt(_ value: Int) -> [ModifierKey] {
    switch value & 0x1f {
    case 0x0:  return [.command]
    case 0x1:  return [.shift, .command]
    case 0x2:  return [.option, .command]
    case 0x3:  return [.option, .shift, .command]
    case 0x4:  return [.control, .command]
    case 0x5:  return [.control, .shift, .command]
    case 0x6:  return [.control, .option, .command]
    case 0x7:  return [.control, .option, .shift, .command]
    case 0x8:  return []
    case 0x9:  return [.shift]
    case 0xa:  return [.option]
    case 0xb:  return [.option, .shift]
    case 0xc:  return [.control]
    case 0xd:  return [.control, .shift]
    case 0xe:  return [.control, .option]
    case 0xf:  return [.control, .option, .shift]
    case 0x18: return [.globe]
    case 0x1c: return [.control, .globe]
    default:   return [.command]
    }
  }

  /// Parses the string form of AXMenuItemCmdModifiers ("cmd", "cmd shift", …).
  private static func parseAXModifiersString(_ str: String) -> [ModifierKey] {
    let parts = str.lowercased().split(separator: " ").map(String.init)
    var result: [ModifierKey] = []
    if parts.contains("cmd")    { result.append(.command) }
    if parts.contains("shift")  { result.append(.shift) }
    if parts.contains("opt")    { result.append(.option) }
    if parts.contains("ctrl")   { result.append(.control) }
    return result
  }

  // MARK: – NSMenu (own process)

  private static func readOwnNSMenu() -> [ShortcutGroup] {
    guard let mainMenu = NSApplication.shared.mainMenu else { return [] }
    var groups: [ShortcutGroup] = []

    for item in mainMenu.items {
      guard let submenu = item.submenu else { continue }
      let shortcuts = readMenuItems(from: submenu)
      guard !shortcuts.isEmpty else { continue }
      groups.append(.init(category: item.title, items: shortcuts))
    }
    return groups
  }

  private static func readMenuItems(from menu: NSMenu) -> [ShortcutItem] {
    var result: [ShortcutItem] = []
    for menuItem in menu.items {
      guard !menuItem.isSeparatorItem else { continue }
      let keyEquiv = menuItem.keyEquivalent
      guard !keyEquiv.isEmpty else { continue }

      let title = menuItem.title
        .replacingOccurrences(of: "…", with: "")
        .trimmingCharacters(in: .whitespaces)

      let mapped = mapKey(keyEquiv)
      result.append(.init(
        modifiers: parseNSModifiers(menuItem.keyEquivalentModifierMask),
        key: mapped.text,
        keySymbolName: mapped.sfSymbol,
        description: title
      ))
    }
    return result
  }

  private static func parseNSModifiers(_ flags: NSEvent.ModifierFlags) -> [ModifierKey] {
    var result: [ModifierKey] = []
    if flags.contains(.command)  { result.append(.command) }
    if flags.contains(.shift)    { result.append(.shift) }
    if flags.contains(.option)   { result.append(.option) }
    if flags.contains(.control)  { result.append(.control) }
    return result
  }

  // MARK: – Key mapping

  /// Returns the display text and optional SF Symbol name for a key.
  private static func mapKey(_ key: String) -> (text: String, sfSymbol: String?) {
    switch key {
    case "":        return ("", nil)
    case " ":       return ("Space", "space")
    case "\r":      return ("↵", "arrow.turn.down.left")
    case "\u{8}":                           // Delete / Backspace
      fallthrough
    case "\u{7f}":  return ("⌫", "delete.left")
    case "\u{1b}":  return ("⎋", "escape")
    case "\t":      return ("⇥", nil)
    case "\u{19}":  return ("⇥", nil)
    case "\u{1c}":  return ("←", "arrow.left")
    case "\u{1d}":  return ("→", "arrow.right")
    case "\u{1e}":  return ("↑", "arrow.up")
    case "\u{1f}":  return ("↓", "arrow.down")
    case "\u{f700}": return ("▲", "arrowtriangle.up.fill")
    case "\u{f701}": return ("▼", "arrowtriangle.down.fill")
    case "\u{f702}": return ("◀", "arrowtriangle.left.fill")
    case "\u{f703}": return ("▶", "arrowtriangle.right.fill")
    // Function keys F1–F12 (Apple private‑use Unicode range).
    case "\u{f704}": return ("F1", nil)
    case "\u{f705}": return ("F2", nil)
    case "\u{f706}": return ("F3", nil)
    case "\u{f707}": return ("F4", nil)
    case "\u{f708}": return ("F5", nil)
    case "\u{f709}": return ("F6", nil)
    case "\u{f70a}": return ("F7", nil)
    case "\u{f70b}": return ("F8", nil)
    case "\u{f70c}": return ("F9", nil)
    case "\u{f70d}": return ("F10", nil)
    case "\u{f70e}": return ("F11", nil)
    case "\u{f70f}": return ("F12", nil)
    case "\u{f728}": return ("⌦", "delete.right")
    case "\u{f729}": return ("⇱", "arrow.up.to.line")
    case "\u{f72b}": return ("⇲", "arrow.down.to.line")
    case "\u{f72c}": return ("⇞", "arrow.up.to.line.compact")
    case "\u{f72d}": return ("⇟", "arrow.down.to.line.compact")
    case "\u{f739}": return ("⌧", "clear")
    case "\u{1F310}": return ("🌐", "globe")
    case "\u{1F3A4}": return ("🎤", "microphone")
    default:
      if key.count == 1 { return (key.uppercased(), nil) }
      return (key, nil)
    }
  }

  // MARK: – AX helpers

  private static func axCopyAttribute(element: AXUIElement, attribute: String) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let elem = value
    else { return nil }
    return (elem as! AXUIElement)
  }

  private static func axCopyAttributeString(element: AXUIElement, attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let str = value as? String
    else { return nil }
    return str
  }

  private static func axCopyAttributeArray(element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &value) == .success,
          let array = value as? [AXUIElement]
    else { return [] }
    return array
  }
}
