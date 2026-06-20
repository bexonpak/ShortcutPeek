//
//  ContentView.swift
//  ShortcutPeek
//
//  Created by Bexon Pak on 15.06.26.
//

import SwiftUI

struct ContentView: View {
  /// Starts `true` if the app already has AX permission at launch.
  @State private var isTrusted: Bool

  init() {
    isTrusted = AccessibilityService.isTrusted
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      // App icon
      Image(systemName: "command")
        .font(.system(size: 48))
        .foregroundStyle(.tint)

      Text("ShortcutPeek")
        .font(.largeTitle.bold())

      Text("Hold ⌘ to view keyboard shortcuts\nfor the current application")
        .font(.body)
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
        .lineSpacing(4)

      Spacer()

      // Status & permission
      VStack(spacing: 12) {
        if isTrusted {
          Label("Accessibility permission granted", systemImage: "checkmark.shield")
            .foregroundColor(.green)
        } else {
          VStack(spacing: 8) {
            Label("Accessibility permission required", systemImage: "exclamationmark.shield")
              .foregroundColor(.orange)

            Button("Grant Accessibility…") {
              AccessibilityService.requestPermission()
              pollUntilTrusted()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
          }
        }
      }
      .padding(.horizontal, 40)

      Spacer()

      // Menu bar hint
      HStack(spacing: 6) {
        Image(systemName: "menubar.rectangle")
          .font(.caption)
        Text("ShortcutPeek is running in the menu bar")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.bottom, 20)
    }
    .frame(width: 380, height: 420)
    // Hidden NSView that closes the window once it has a real NSWindow
    // reference (reliable even when onAppear fires too early).
    .background(WindowCloser(shouldClose: isTrusted))
  }

  /// Polls AX permission every 500 ms and closes the window once granted.
  private func pollUntilTrusted() {
    Task {
      while !AccessibilityService.isTrusted {
        try? await Task.sleep(nanoseconds: 500_000_000)
      }
      isTrusted = true
      NSApp.windows.filter(\.isVisible).forEach { $0.close() }
    }
  }
}

// MARK: – Window closer

/// An invisible NSView that closes its enclosing window immediately
/// when it enters the view hierarchy (if `shouldClose` is true).
private struct WindowCloser: NSViewRepresentable {
  let shouldClose: Bool

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    if shouldClose {
      DispatchQueue.main.async { [weak view] in
        guard let window = view?.window else { return }
        window.close()
      }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}
}
