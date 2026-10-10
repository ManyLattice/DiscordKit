//
//  ComponentEncodingTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class ComponentEncodingTests: XCTestCase {

    //MARK: - Tests

    func testSelectMenuEncodesOptions() throws {
        let menu = try encodedComponent {
            SelectMenu(id: "nation", placeholder: "Страна", maxValues: 2, options: [
                SelectMenuOption("Россия", value: "ru", isDefault: true),
                SelectMenuOption("Казахстан", value: "kz", description: "Степь")
            ])
        }

        XCTAssertEqual(menu["type"] as? Int, 3)
        XCTAssertEqual(menu["custom_id"] as? String, "nation")
        XCTAssertEqual(menu["placeholder"] as? String, "Страна")
        XCTAssertEqual(menu["max_values"] as? Int, 2)
        let options = try XCTUnwrap(menu["options"] as? [[String: Any]])
        XCTAssertEqual(options.map { $0["value"] as? String }, ["ru", "kz"])
        XCTAssertEqual(options[0]["default"] as? Bool, true)
        XCTAssertEqual(options[1]["description"] as? String, "Степь")
    }

    func testEntitySelectMenusEncodeTheirTypes() throws {
        let types = try [EntitySelectKind.user, .role, .mentionable, .channel].map { kind in
            try encodedComponent { EntitySelectMenu(kind, id: "pick") }["type"] as? Int
        }

        XCTAssertEqual(types, [5, 6, 7, 8])
    }

    func testChannelSelectEncodesChannelTypes() throws {
        let menu = try encodedComponent {
            EntitySelectMenu(.channel, id: "room", channelTypes: [.voice])
        }

        XCTAssertEqual(menu["channel_types"] as? [Int], [2])
    }

    func testUpdateMessageResponseEncodesType7() throws {
        let response = InteractionResponse(type: .updateMessage, data: .message(.init(content: "Крутим", components: [])))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(response)) as? [String: Any])
        let data = try XCTUnwrap(object["data"] as? [String: Any])

        XCTAssertEqual(object["type"] as? Int, 7)
        XCTAssertEqual(data["content"] as? String, "Крутим")
        XCTAssertEqual((data["components"] as? [Any])?.count, 0)
    }

    func testDeferredUpdateResponseHasNoData() throws {
        let response = InteractionResponse(type: .deferredUpdateMessage, data: nil)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(response)) as? [String: Any])

        XCTAssertEqual(object["type"] as? Int, 6)
        XCTAssertNil(object["data"])
    }

    //MARK: - Private methods

    private func encodedComponent(@ComponentBuilder _ components: () -> [Component]) throws -> [String: Any] {
        let row = ActionRow(components)
        let object = try JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(row)) as? [String: Any]
        let inner = try XCTUnwrap(object?["components"] as? [[String: Any]])
        return try XCTUnwrap(inner.first)
    }
}
