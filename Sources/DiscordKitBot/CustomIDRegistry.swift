//
//  CustomIDRegistry.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation

/// Finds the handler for a custom ID by exact match, falling back to the longest matching prefix
struct CustomIDRegistry<Handler> {

    //MARK: - Properties

    private var exact: [String: Handler] = [:]
    private var prefixed: [String: Handler] = [:]

    //MARK: - Public methods

    mutating func register(_ customID: String, handler: Handler) {
        exact[customID] = handler
    }

    mutating func register(prefix: String, handler: Handler) {
        prefixed[prefix] = handler
    }

    func handler(for customID: String) -> Handler? {
        if let handler = exact[customID] {
            return handler
        }
        return prefixed
            .filter { customID.hasPrefix($0.key) }
            .max { $0.key.count < $1.key.count }?
            .value
    }
}
