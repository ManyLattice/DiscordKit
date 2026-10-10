//
//  ChannelOption.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// An option for an application command that accepts a channel
public struct ChannelOption: CommandOption {
    public init(_ name: String, description: String, `required`: Bool? = nil, channelTypes: [ChannelType]? = nil) {
        type = .channel

        self.name = name
        self.description = description
        self.required = `required`
        self.channel_types = channelTypes
    }

    public let type: CommandOptionType

    public let name: String

    public let description: String

    public var required: Bool?

    /// Channel types the user can pick from, any type if `nil`
    public let channel_types: [ChannelType]?
}
