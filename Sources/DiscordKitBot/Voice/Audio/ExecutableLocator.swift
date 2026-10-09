//
//  ExecutableLocator.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum ExecutableLocator {

    //MARK: - Public methods

    // Apps started from Finder or launchd get a minimal PATH without Homebrew.
    public static func find(_ name: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        let pathEntries = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let candidates = pathEntries + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        return candidates
            .map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
