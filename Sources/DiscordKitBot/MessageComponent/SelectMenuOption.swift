//
//  SelectMenuOption.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// One choice in a ``SelectMenu``
public struct SelectMenuOption: Encodable {
    public let label: String
    public let value: String
    public let description: String?
    public let emoji: Emoji?
    public let `default`: Bool?

    public init(_ label: String, value: String, description: String? = nil, emoji: Emoji? = nil, isDefault: Bool? = nil) {
        self.label = label
        self.value = value
        self.description = description
        self.emoji = emoji
        self.default = isDefault
    }
}
