//
//  SelectMenu.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// A select menu with text choices, takes a whole ``ActionRow``
public struct SelectMenu: Component {

    //MARK: - Properties

    public let type: MessageComponentTypes = .selectMenu
    public let custom_id: String
    public let options: [SelectMenuOption]
    public let placeholder: String?
    public let min_values: Int?
    public let max_values: Int?
    fileprivate(set) var disabled: Bool?

    //MARK: - Init

    public init(id: String, placeholder: String? = nil, minValues: Int? = nil, maxValues: Int? = nil, options: [SelectMenuOption]) {
        assert((1...25).contains(options.count), "A select menu needs 1 to 25 options")
        self.custom_id = id
        self.options = options
        self.placeholder = placeholder
        self.min_values = minValues
        self.max_values = maxValues
    }

    //MARK: - Public methods

    public func disabled(_ disabled: Bool = true) -> Self {
        var menu = self
        menu.disabled = disabled
        return menu
    }
}
