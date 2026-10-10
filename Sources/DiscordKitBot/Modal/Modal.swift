//
//  Modal.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// A popup form with text fields, shown in response to a command or a component
public struct Modal: Encodable {

    //MARK: - Properties

    public let custom_id: String
    public let title: String
    public let inputs: [TextInput]

    private enum CodingKeys: CodingKey {
        case custom_id
        case title
        case components
    }

    //MARK: - Init

    public init(id: String, title: String, inputs: [TextInput]) {
        assert((1...5).contains(inputs.count), "A modal needs 1 to 5 text inputs")
        self.custom_id = id
        self.title = title
        self.inputs = inputs
    }

    //MARK: - Public methods

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(custom_id, forKey: .custom_id)
        try container.encode(title, forKey: .title)
        var rows = container.nestedUnkeyedContainer(forKey: .components)
        for input in inputs {
            try rows.encode(ActionRow { input })
        }
    }
}
