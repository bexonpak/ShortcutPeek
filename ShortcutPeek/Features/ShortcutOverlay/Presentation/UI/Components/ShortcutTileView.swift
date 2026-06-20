//
//  ShortcutTileView.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 20.06.26.
//

import SwiftUI

/// A single shortcut tile showing the key combination and description.
struct ShortcutTileView: View {
  let item: ShortcutItem
  let targetPID: pid_t
  let onExecuted: (@Sendable () -> Void)?

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 8) {
      // Key badge
      HStack(spacing: 2) {
        ForEach(item.modifiers) { modifier in
          Image(systemName: modifier.sfSymbolName)
            .font(.system(size: 12, weight: .regular))
        }
        if let name = item.keySymbolName {
          Image(systemName: name)
            .font(.system(size: 12, weight: .regular))
        } else {
          Text(item.key)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
      }
      .foregroundColor(.primary)
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 5)
          .fill(.secondary.opacity(0.6))
      )
      .fixedSize()

      // Description
      Text(item.description)
        .font(.system(size: 12))
        .foregroundColor(.primary.opacity(0.8))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(.secondary.opacity(isHovered ? 0.3 : 0))
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    )
    .contentShape(Rectangle())
    .onHover { hovering in
      isHovered = hovering
    }
    .onTapGesture {
      ShortcutExecutor.execute(item, targetPID: targetPID)
      onExecuted?()
    }
  }
}
