//
//  OverlayView.swift
//  CheatKey
//
//  Created by Bexon Pak on 15.06.26.
//

import SwiftUI

/// View model used *inside* the overlay to describe its static content.
/// It is distinct from the feature-level `OverlayViewModel` which manages
/// lifecycle.
struct OverlayPanelViewModel: Sendable {
  let shortcutGroups: [ShortcutGroup]
  let appName: String
  let appIcon: Image?
  let targetPID: pid_t
  let onShortcutExecuted: (@Sendable () -> Void)?
}

// MARK: – Window drag modifier

private extension View {
  func windowDrag() -> some View {
    modifier(WindowDragHandler())
  }
}

private struct WindowDragHandler: ViewModifier {
  @State private var dragStart: CGPoint?

  func body(content: Content) -> some View {
    content.gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          guard let window = NSApp.windows.first(where: { $0.isKeyWindow || $0.level == .floating }) else { return }
          if dragStart == nil { dragStart = window.frame.origin }
          window.setFrameOrigin(NSPoint(
            x: dragStart!.x + value.translation.width,
            y: dragStart!.y - value.translation.height
          ))
        }
        .onEnded { _ in dragStart = nil }
    )
  }
}

// MARK: – OverlayView

/// The floating card that lists an application's keyboard shortcuts
/// in a compact grid layout.
struct OverlayView: View {

  let viewModel: OverlayPanelViewModel

  // MARK: – Constants

  private let columns = Array(
    repeating: GridItem(.flexible(minimum: 110), spacing: 8),
    count: 3
  )

  // MARK: – Body
  
  var body: some View {
    if #available(macOS 26.0, *) {
      content
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 14))
    } else {
      content
        .background(backgroundFill)
    }
  }
  
  private var content: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .windowDrag()

      Divider()
        .overlay(.white.opacity(0.15))
        .padding(.horizontal, 12)

      shortcutGrid
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    .frame(width: 820)
  }

  // MARK: – Header

  private var header: some View {
    HStack(spacing: 10) {
      iconView
        .frame(width: 28, height: 28)

      Text(viewModel.appName)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.primary)

      Spacer()

      Text("Keyboard Shortcuts")
        .font(.system(size: 11, weight: .regular))
        .foregroundColor(.primary.opacity(0.5))
    }
  }

  @ViewBuilder
  private var iconView: some View {
    if let icon = viewModel.appIcon {
      icon
        .resizable()
        .aspectRatio(contentMode: .fit)
    } else {
      Image(systemName: "app.fill")
        .resizable()
        .aspectRatio(contentMode: .fit)
    }
  }

  // MARK: – Shortcut Grid

  private var shortcutGrid: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(alignment: .leading, spacing: 20) {
        ForEach(viewModel.shortcutGroups) { group in
          shortcutGroupGrid(group)
        }
      }
      .padding(.vertical, 4)
    }
    .frame(maxHeight: 600)
  }

  // MARK: – Group Grid

  private func shortcutGroupGrid(_ group: ShortcutGroup) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(group.category.uppercased())
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundColor(.primary.opacity(0.45))
        .padding(.leading, 2)

      LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
        ForEach(group.items) { item in
          shortcutTile(item)
        }
      }
    }
  }

  // MARK: – Grid Tile

  private func shortcutTile(_ item: ShortcutItem) -> some View {
    ShortcutTileView(item: item, targetPID: viewModel.targetPID) { [viewModel] in
      viewModel.onShortcutExecuted?()
    }
  }

  // MARK: – Background

  private var backgroundFill: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 14)
        .fill(
          .ultraThinMaterial
        )

      RoundedRectangle(cornerRadius: 14)
        .stroke(.white.opacity(0.15), lineWidth: 1)
    }
  }
}

// MARK: – Shortcut tile

private struct ShortcutTileView: View {
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
