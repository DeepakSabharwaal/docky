//
//  ChromeProfileTileView.swift
//  Docky
//
//  Renders a single Chrome profile as a dock tile. Shows Chrome's icon
//  with a profile-avatar badge in the bottom-right corner. Clicking
//  launches Chrome into that profile.
//

import AppKit
import SwiftUI

struct ChromeProfileTileView: View {
    let tile: ChromeProfileTile
    let clipShape: DockClipShape
    let transparencyCompensationInset: CGFloat

    @ObservedObject private var chromeService = ChromeProfileService.shared

    private var chromeIcon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ChromeProfile.chromeBundleID) {
            return IconCacheService.shared.icon(forFileURL: url)
        }
        return NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
    }

    private var avatarImage: NSImage? {
        guard let avatarURL = chromeService.profile(forDirectory: tile.profileDirectory)?.avatarURL else {
            return nil
        }
        return NSImage(contentsOf: avatarURL)
    }

    var body: some View {
        Button {
            ChromeProfileService.shared.launch(profileDirectory: tile.profileDirectory)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: chromeIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(transparencyCompensationInset)

                profileBadge
                    .offset(x: 3, y: 3)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var profileBadge: some View {
        if let avatar = avatarImage {
            Image(nsImage: avatar)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 18, height: 18)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
        } else {
            Text(tile.profileName.prefix(1).uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(profileColor)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
        }
    }

    private var profileColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow]
        let index = abs(tile.profileDirectory.hashValue) % colors.count
        return colors[index]
    }
}
