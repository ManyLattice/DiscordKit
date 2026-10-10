//
//  EntitySelectMenu.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// A select menu filled by Discord with users, roles or channels, takes a whole ``ActionRow``
public struct EntitySelectMenu: Component {

    //MARK: - Properties

    public let type: MessageComponentTypes
    public let custom_id: String
    public let placeholder: String?
    public let min_values: Int?
    public let max_values: Int?
    public let channel_types: [ChannelType]?
    fileprivate(set) var disabled: Bool?

    //MARK: - Init

    public init(
        _ kind: EntitySelectKind, id: String, placeholder: String? = nil,
        minValues: Int? = nil, maxValues: Int? = nil, channelTypes: [ChannelType]? = nil
    ) {
        assert(channelTypes == nil || kind == .channel, "Channel types apply only to channel select menus")
        self.type = kind.componentType
        self.custom_id = id
        self.placeholder = placeholder
        self.min_values = minValues
        self.max_values = maxValues
        self.channel_types = channelTypes
    }

    //MARK: - Public methods

    public func disabled(_ disabled: Bool = true) -> Self {
        var menu = self
        menu.disabled = disabled
        return menu
    }
}
