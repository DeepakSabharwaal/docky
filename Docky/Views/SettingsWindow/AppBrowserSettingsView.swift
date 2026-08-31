//
//  AppBrowserSettingsView.swift
//  Docky
//
//  Browse all installed apps (including Parall shortcuts) and pin them to the dock.
//

import AppKit
import Combine
import SwiftUI

private struct InstalledApp: Identifiable, Equatable {
    let id: String          // bundle identifier
    let bundleIdentifier: String
    let displayName: String
    let url: URL

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

@MainActor
private final class AppBrowserModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var searchText: String = ""

    var filtered: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        let q = searchText.lowercased()
        return apps.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.bundleIdentifier.lowercased().contains(q)
        }
    }

    func load() {
        let dirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var found: [InstalledApp] = []
        let fm = FileManager.default

        for dir in dirs {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.pathExtension == "app" {
                guard let bundle = Bundle(url: entry),
                      let bid = bundle.bundleIdentifier else { continue }
                let name = bundle.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? bundle.infoDictionary?["CFBundleName"] as? String
                    ?? entry.deletingPathExtension().lastPathComponent
                found.append(InstalledApp(
                    id: bid,
                    bundleIdentifier: bid,
                    displayName: name,
                    url: entry
                ))
            }
        }

        apps = found.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

struct AppBrowserSettingsView: View {
    @StateObject private var model = AppBrowserModel()
    @State private var tileStore = TileStore.shared

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $model.searchText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            if model.apps.isEmpty {
                Text("Scanning apps…")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.filtered.isEmpty {
                Text("No apps match \"\(model.searchText)\"")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.filtered) { app in
                            AppRow(app: app, isPinned: isPinned(app.bundleIdentifier))
                            Divider().padding(.leading, 56)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .onAppear { model.load() }
    }

    private func isPinned(_ bundleID: String) -> Bool {
        tileStore.pinnedItems.contains {
            $0.kind == .app && $0.bundleIdentifier == bundleID
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp
    let isPinned: Bool
    @State private var tileStore = TileStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .fontWeight(.medium)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isPinned },
                set: { on in
                    _ = tileStore.setPinnedApp(bundleIdentifier: app.bundleIdentifier, pinned: on)
                }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search apps…", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
