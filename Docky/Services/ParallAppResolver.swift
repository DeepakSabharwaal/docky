//
//  ParallAppResolver.swift
//  Docky
//
//  Detects Parall-launched app instances by matching their --user-data-dir
//  argument against known Parall wrapper apps, then provides the correct
//  display name (e.g. "Claude Work" instead of "Claude").
//

import Darwin
import Foundation

final class ParallAppResolver {
    static let shared = ParallAppResolver()
    private init() { load() }

    // ParallDataStorage path → wrapper display name
    private var nameByDataStorage: [String: String] = [:]

    func load() {
        nameByDataStorage = [:]
        let dirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications")
        ]
        for dir in dirs {
            let entries = (try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )) ?? []
            for entry in entries where entry.pathExtension == "app" {
                guard
                    let bundle = Bundle(url: entry),
                    let bid = bundle.bundleIdentifier,
                    bid.hasPrefix("app.parall.mac."),
                    let storage = bundle.infoDictionary?["ParallDataStorage"] as? String,
                    !storage.isEmpty,
                    let name = (bundle.infoDictionary?["CFBundleDisplayName"]
                        ?? bundle.infoDictionary?["CFBundleName"]) as? String
                else { continue }
                nameByDataStorage[storage] = name
            }
        }
    }

    /// Returns the Parall display name for `pid` if it was launched by a
    /// Parall wrapper, or `fallback` otherwise.
    func displayName(for pid: pid_t, fallback: String) -> String {
        guard !nameByDataStorage.isEmpty,
              let args = processArguments(pid: pid) else { return fallback }
        for arg in args {
            if let dir = userDataDir(from: arg),
               let name = nameByDataStorage[dir] {
                return name
            }
        }
        return fallback
    }

    // MARK: - Private

    private func userDataDir(from arg: String) -> String? {
        let prefix = "--user-data-dir="
        guard arg.hasPrefix(prefix) else { return nil }
        return String(arg.dropFirst(prefix.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private func processArguments(pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: size_t = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        // First 4 bytes: argc (number of arguments, not counting argv[0])
        var argc: Int32 = 0
        withUnsafeMutableBytes(of: &argc) { ptr in
            buffer.withUnsafeBytes { buf in
                ptr.copyMemory(from: UnsafeRawBufferPointer(start: buf.baseAddress, count: 4))
            }
        }

        // Skip argc field, then the executable path (argv[0])
        var offset = 4
        while offset < size && buffer[offset] != 0 { offset += 1 }
        // Skip alignment nulls
        while offset < size && buffer[offset] == 0 { offset += 1 }

        // Read the remaining argc argument strings
        var args: [String] = []
        for _ in 0..<Int(argc) {
            guard offset < size else { break }
            let start = offset
            while offset < size && buffer[offset] != 0 { offset += 1 }
            if let str = String(bytes: buffer[start..<offset], encoding: .utf8) {
                args.append(str)
            }
            offset += 1
        }
        return args
    }
}
