//
//  ModalSubmitComponent.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation

/// A component of a submitted modal: an input with a value, or a row or label wrapping inputs
struct ModalSubmitComponent: Decodable {

    //MARK: - Properties

    let custom_id: String?
    let value: String?
    let children: [ModalSubmitComponent]

    var inputValues: [(String, String)] {
        var pairs = children.flatMap(\.inputValues)
        if let custom_id, let value {
            pairs.append((custom_id, value))
        }
        return pairs
    }

    private enum CodingKeys: CodingKey {
        case custom_id
        case value
        case components
        case component
    }

    //MARK: - Init

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        custom_id = try container.decodeIfPresent(String.self, forKey: .custom_id)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        let rowChildren = try container.decodeIfPresent([ModalSubmitComponent].self, forKey: .components) ?? []
        let labelChild = try container.decodeIfPresent(ModalSubmitComponent.self, forKey: .component)
        children = rowChildren + (labelChild.map { [$0] } ?? [])
    }
}
