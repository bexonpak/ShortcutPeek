//
//  SettingsView.swift
//  CheatKey
//
//  Created by Bexon Pak on 18.06.26.
//

import ServiceManagement
import SwiftUI

// MARK: – GitHub release model (subset)

private struct GitHubRelease: Decodable {
  let tagName: String
  let htmlUrl: String
  let publishedAt: String

  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case htmlUrl = "html_url"
    case publishedAt = "published_at"
  }
}

// MARK: – Settings

struct SettingsView: View {
  @State private var launchAtLogin = false
  @State private var updateState: UpdateState = .idle
  @AppStorage("holdDurationTag") private var holdDurationTag = 1

  /// Repository to check for updates.
  private static let repo = "bexonpak/CheatKey"

  private enum UpdateState {
    case idle
    case checking
    case upToDate(current: String)
    case available(version: String, url: String)
    case error(String)
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      ?? "–"
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 10) {
        Image(systemName: "command")
          .font(.system(size: 20))
          .foregroundStyle(.tint)

        Text("CheatKey Settings")
          .font(.headline)

        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 16)

      Divider()
        .padding(.horizontal, 12)

      Form {
        // ── Login item ──
        Toggle(isOn: $launchAtLogin) {
          HStack {
            Text("Launch at Login")
            Spacer()
            Text("Automatically start CheatKey when you log in")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .onChange(of: launchAtLogin) { _, newValue in
          toggleLoginItem(newValue)
        }

        // ── Hold duration ──
        Picker("Hold Duration", selection: $holdDurationTag) {
          Text("Fast").tag(0)
          Text("Default").tag(1)
          Text("Slow").tag(2)
        }

        // ── Version & updates ──
        HStack {
          Text("Version")
          Spacer()
          Text(appVersion)
            .foregroundColor(.secondary)
        }

        HStack {
          Spacer()
          updateButton
          Spacer()
        }
      }
      .formStyle(.grouped)
    }
    .frame(width: 440, height: 300)
    .onAppear {
      launchAtLogin = SMAppService.mainApp.status == .enabled
    }
  }

  // MARK: – Update button

  @ViewBuilder
  private var updateButton: some View {
    switch updateState {
    case .idle:
      Button("Check for Updates") { checkForUpdates() }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)

    case .checking:
      HStack(spacing: 6) {
        ProgressView()
          .scaleEffect(0.7)
          .frame(height: 12)
        Text("Checking…")
          .font(.caption)
          .foregroundColor(.secondary)
      }

    case .upToDate(let current):
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle")
          .foregroundColor(.green)
          .font(.caption)
        Text("Up to date (\(current))")
          .font(.caption)
          .foregroundColor(.secondary)
      }

    case .available(let version, let url):
      VStack(spacing: 8) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.down.circle")
            .foregroundColor(.blue)
            .font(.caption)
          Text("New version \(version)")
            .font(.caption)
            .foregroundColor(.blue)
        }
        Button("Download") {
          if let link = URL(string: url) {
            NSWorkspace.shared.open(link)
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
      }

    case .error(let msg):
      HStack(spacing: 4) {
        Image(systemName: "exclamationmark.triangle")
          .foregroundColor(.orange)
          .font(.caption)
        Text(msg)
          .font(.caption)
          .foregroundColor(.orange)
      }
    }
  }

  // MARK: – Actions

  private func toggleLoginItem(_ enable: Bool) {
    do {
      if enable {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      launchAtLogin = !enable
      print("Failed to \(enable ? "register" : "unregister") login item: \(error)")
    }
  }

  private func checkForUpdates() {
    updateState = .checking

    Task {
      guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
        updateState = .error("Invalid repository URL")
        return
      }

      var request = URLRequest(url: url)
      request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

      do {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
          updateState = .error("Cannot connect to update server")
          return
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName
          .trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

        if latestVersion.compare(appVersion, options: .numeric) == .orderedDescending {
          updateState = .available(version: latestVersion, url: release.htmlUrl)
        } else {
          updateState = .upToDate(current: appVersion)
        }
      } catch {
        updateState = .error("Update check failed")
      }
    }
  }
}

#Preview {
  SettingsView()
}
