//
//  TextInput.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// A text field in a ``Modal``
public struct TextInput: Component {

    //MARK: - Properties

    public let type: MessageComponentTypes = .textInput
    public let custom_id: String
    public let label: String
    public let style: TextInputStyle
    public let placeholder: String?
    /// Text prefilled in the field
    public let value: String?
    public let min_length: Int?
    public let max_length: Int?
    public let required: Bool?

    //MARK: - Init

    public init(
        id: String, label: String, style: TextInputStyle = .short, placeholder: String? = nil,
        value: String? = nil, minLength: Int? = nil, maxLength: Int? = nil, required: Bool? = nil
    ) {
        self.custom_id = id
        self.label = label
        self.style = style
        self.placeholder = placeholder
        self.value = value
        self.min_length = minLength
        self.max_length = maxLength
        self.required = required
    }
}
