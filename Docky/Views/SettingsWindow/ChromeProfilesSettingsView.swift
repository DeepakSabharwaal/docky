//
//  ChromeProfilesSettingsView.swift
//  Docky
//
//  Settings pane to pin/unpin Chrome profile tiles.
//

import SwiftUI

struct ChromeProfilesSettingsView: View {
    @State private var service = ChromeProfileService.shared
    @State private var tileStore = TileStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pin Chrome profiles as dock tiles. Each tile opens Chrome directly into that profile.")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                if service.profiles.isEmpty {
                    Text("No Chrome profiles found.\nMake sure Google Chrome is installed and has been launched at least once.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(service.profiles) { profile in
                            ProfileRow(profile: profile, isPinned: isPinned(profile))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                            if profile.id != service.profiles.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button("Refresh Profiles") {
                    service.loadProfiles()
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func isPinned(_ profile: ChromeProfile) -> Bool {
        tileStore.pinnedItems.contains {
            $0.kind == .chromeProfile && $0.chromeProfileDirectory == profile.directory
        }
    }
}

private struct ProfileRow: View {
    let profile: ChromeProfile
    let isPinned: Bool

    @State private var tileStore = TileStore.shared

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(profile: profile)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .fontWeight(.medium)
                if let email = profile.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(profile.directory)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isPinned },
                set: { on in
                    if on {
                        let item = PinnedTileItem.chromeProfile(directory: profile.directory, name: profile.name)
                        tileStore.insertPinnedItem(item, at: tileStore.pinnedItems.count)
                    } else {
                        tileStore.removePinnedItems {
                            $0.kind == .chromeProfile && $0.chromeProfileDirectory == profile.directory
                        }
                    }
                }
            ))
            .labelsHidden()
        }
    }
}

private struct ProfileAvatar: View {
    let profile: ChromeProfile

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 36, height: 36)

            if let url = profile.avatarURL,
               let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Text(profile.initialLetter())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .indigo, .pink]
        let hash = profile.directory.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }
}
