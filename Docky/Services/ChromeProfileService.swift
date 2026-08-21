//
//  ChromeProfileService.swift
//  Docky
//
//  Reads Google Chrome's Local State file to enumerate profiles and
//  provides a launch entry point that opens Chrome into a specific profile.
//

import AppKit
import Foundation

struct ChromeProfile: Identifiable, Equatable {
    let id: String
    let directory: String
    let name: String
    let email: String?
    let avatarURL: URL?

    static let chromeBundleID = "com.google.Chrome"

    func initialLetter() -> String {
        String(name.prefix(1).uppercased())
    }
}

@MainActor
final class ChromeProfileService: ObservableObject {
    static let shared = ChromeProfileService()

    @Published private(set) var profiles: [ChromeProfile] = []

    private let chromeDataDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Google/Chrome")

    private var localStatePath: URL {
        chromeDataDir.appendingPathComponent("Local State")
    }

    private init() {
        loadProfiles()
    }

    func loadProfiles() {
        guard let data = try? Data(contentsOf: localStatePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileSection = json["profile"] as? [String: Any],
              let infoCache = profileSection["info_cache"] as? [String: [String: Any]]
        else {
            profiles = []
            return
        }

        profiles = infoCache.compactMap { directory, info -> ChromeProfile? in
            guard let name = info["name"] as? String, !name.isEmpty else { return nil }
            let email = info["user_name"] as? String
            let avatarPath = chromeDataDir
                .appendingPathComponent(directory)
                .appendingPathComponent("Google Profile Picture.png")
            let avatarURL: URL? = FileManager.default.fileExists(atPath: avatarPath.path)
                ? avatarPath
                : nil
            return ChromeProfile(
                id: directory,
                directory: directory,
                name: name,
                email: email,
                avatarURL: avatarURL
            )
        }.sorted { $0.directory < $1.directory }
    }

    func launch(profileDirectory: String) {
        guard let chromeURL = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: ChromeProfile.chromeBundleID)
        else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--profile-directory=\(profileDirectory)"]
        NSWorkspace.shared.openApplication(at: chromeURL, configuration: config) { _, _ in }
    }

    func profile(forDirectory directory: String) -> ChromeProfile? {
        profiles.first { $0.directory == directory }
    }
}
