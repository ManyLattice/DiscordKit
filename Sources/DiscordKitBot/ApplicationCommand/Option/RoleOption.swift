//
//  RoleOption.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// An option for an application command that accepts a role
public struct RoleOption: CommandOption {
    public init(_ name: String, description: String, `required`: Bool? = nil) {
        type = .role

        self.name = name
        self.description = description
        self.required = `required`
    }

    public let type: CommandOptionType

    public let name: String

    public let description: String

    public var required: Bool?
}
