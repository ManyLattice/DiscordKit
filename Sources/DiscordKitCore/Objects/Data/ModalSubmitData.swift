//
//  ModalSubmitData.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation

/// The data payload of a submitted modal
public struct ModalSubmitData: Decodable {

    //MARK: - Properties

    public let custom_id: String
    /// Text the user entered, keyed by the custom ID of each input
    public let values: [String: String]

    private enum CodingKeys: CodingKey {
        case custom_id
        case components
    }

    //MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        custom_id = try container.decode(String.self, forKey: .custom_id)
        let components = try container.decodeIfPresent([ModalSubmitComponent].self, forKey: .components) ?? []
        values = Dictionary(components.flatMap(\.inputValues), uniquingKeysWith: { first, _ in first })
    }
}
