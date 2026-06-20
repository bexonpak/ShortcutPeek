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
  let showsCloseButton: Bool
  let onClose: (@Sendable () -> Void)?
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

      if viewModel.showsCloseButton {
        Button {
          viewModel.onClose?()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16, weight: .regular))
            .foregroundColor(.primary.opacity(0.4))
        }
        .buttonStyle(.plain)
        .help("Close")
        .padding(.leading, 6)
      }
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
