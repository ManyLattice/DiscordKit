//
//  ComponentInteractionTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class ComponentInteractionTests: XCTestCase {

    //MARK: - Properties

    private let rest = DiscordREST()

    //MARK: - Tests

    func testButtonClickDecodesWithMessage() throws {
        let interaction = try component(data: #"{"custom_id": "casino:spin", "component_type": 2}"#)

        XCTAssertEqual(interaction.customID, "casino:spin")
        XCTAssertEqual(interaction.componentType, .button)
        XCTAssertEqual(interaction.values, [])
        XCTAssertEqual(interaction.userID, "444")
        XCTAssertEqual(interaction.guildID, "111")
        XCTAssertEqual(interaction.message?.id, "800")
    }

    func testMessageWithUnknownComponentTypeDecodes() throws {
        let interaction = try component(data: #"{"custom_id": "casino:spin", "component_type": 2}"#)

        XCTAssertEqual(interaction.message?.components?.map(\.type), [.actionRow, .unknown])
    }

    func testStringSelectDecodesValues() throws {
        let interaction = try component(data: #"{"custom_id": "nation", "component_type": 3, "values": ["ru", "kz"]}"#)

        XCTAssertEqual(interaction.componentType, .selectMenu)
        XCTAssertEqual(interaction.values, ["ru", "kz"])
    }

    func testUserSelectDecodesResolvedUsers() throws {
        let interaction = try component(data: """
        {"custom_id": "victim", "component_type": 5, "values": ["555"],
         "resolved": {"users": {"555": {"id": "555", "username": "victim", "discriminator": "0", "avatar": null}}}}
        """)

        XCTAssertEqual(interaction.componentType, .userSelect)
        XCTAssertEqual(interaction.values, ["555"])
        XCTAssertEqual(interaction.resolved?.users?["555"]?.username, "victim")
    }

    //MARK: - Private methods

    private func component(data: String) throws -> ComponentInteraction {
        let json = """
        {
          "id": "900", "application_id": "100", "type": 3, "token": "interaction-token", "version": 1,
          "guild_id": "111", "channel_id": "222",
          "member": {"user": {"id": "444", "username": "player", "discriminator": "0", "avatar": null},
                     "roles": [], "joined_at": "2023-10-15T10:00:00.123000+00:00", "deaf": false, "mute": false},
          "message": {
            "id": "800", "channel_id": "222", "type": 0, "content": "Казино", "tts": false,
            "author": {"id": "100", "username": "BunkerBot", "discriminator": "0", "avatar": null, "bot": true},
            "timestamp": "2026-10-10T07:00:00.000000+00:00", "edited_timestamp": null,
            "mention_everyone": false, "mentions": [], "mention_roles": [], "attachments": [], "embeds": [],
            "pinned": false, "flags": 0,
            "components": [
              {"type": 1, "components": [{"type": 2, "style": 1, "label": "Spin", "custom_id": "casino:spin"}]},
              {"type": 17, "components": []}
            ]
          },
          "data": \(data)
        }
        """
        let interaction = try DiscordREST.decoder.decode(Interaction.self, from: Data(json.utf8))
        var componentData: Interaction.Data.MessageComponentData?
        if case .messageComponent(let data) = interaction.data {
            componentData = data
        }
        return ComponentInteraction(
            data: try XCTUnwrap(componentData), interaction: interaction, rest: rest, applicationID: "100"
        )
    }
}
