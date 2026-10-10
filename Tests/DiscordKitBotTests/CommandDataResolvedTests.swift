//
//  CommandDataResolvedTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class CommandDataResolvedTests: XCTestCase {

    //MARK: - Properties

    private let rest = DiscordREST()

    //MARK: - Tests

    func testUserOptionResolvesUserAndMember() throws {
        let data = try commandData()

        XCTAssertEqual(data.user(of: "target")?.username, "victim")
        XCTAssertEqual(data.member(of: "target")?.nick, "Жертва")
        XCTAssertEqual(data.member(of: "target")?.roles, ["555"])
        XCTAssertEqual(data.optionValue(of: "target") as String?, "444")
    }

    func testChannelOptionResolvesChannel() throws {
        let channel = try XCTUnwrap(commandData().channel(of: "room"))

        XCTAssertEqual(channel.name, "Бункер")
        XCTAssertEqual(channel.type, .voice)
    }

    func testRoleOptionResolvesRole() throws {
        let role = try XCTUnwrap(commandData().role(of: "rank"))

        XCTAssertEqual(role.name, "Выживший")
        XCTAssertTrue(role.permissions.contains(.administrator))
    }

    func testMentionableOptionResolvesRole() throws {
        let data = try commandData()

        XCTAssertEqual(data.role(of: "who")?.id, "555")
        XCTAssertNil(data.user(of: "who"))
    }

    func testAttachmentOptionResolvesAttachment() throws {
        let attachment = try XCTUnwrap(commandData().attachment(of: "file"))

        XCTAssertEqual(attachment.filename, "map.png")
        XCTAssertEqual(attachment.url, "https://cdn.discordapp.com/map.png")
    }

    func testResolvedGettersReturnNilForMissingOrWrongOption() throws {
        let data = try commandData()

        XCTAssertNil(data.user(of: "missing"))
        XCTAssertNil(data.channel(of: "target"))
        XCTAssertNil(data.role(of: "room"))
    }

    //MARK: - Private methods

    private func commandData() throws -> CommandData {
        let interaction = try DiscordREST.decoder.decode(Interaction.self, from: Data(Self.interactionJSON.utf8))
        var commandData: Interaction.Data.AppCommandData?
        if case .applicationCommand(let data) = interaction.data {
            commandData = data
        }
        let command = try XCTUnwrap(commandData)
        return CommandData(
            optionValues: command.options ?? [], resolved: command.resolved,
            rest: rest, applicationID: "100", interactionID: interaction.id, token: interaction.token
        )
    }

    private static let interactionJSON = """
    {
      "id": "900", "application_id": "100", "type": 2, "token": "interaction-token", "version": 1,
      "guild_id": "111", "channel_id": "222",
      "data": {
        "id": "300", "name": "pick", "type": 1,
        "options": [
          {"name": "target", "type": 6, "value": "444"},
          {"name": "room", "type": 7, "value": "333"},
          {"name": "rank", "type": 8, "value": "555"},
          {"name": "who", "type": 9, "value": "555"},
          {"name": "file", "type": 11, "value": "666"}
        ],
        "resolved": {
          "users": {
            "444": {"id": "444", "username": "victim", "discriminator": "0", "global_name": null, "avatar": null, "public_flags": 0}
          },
          "members": {
            "444": {"nick": "Жертва", "avatar": null, "roles": ["555"], "joined_at": "2023-10-15T10:00:00.123000+00:00",
                    "premium_since": null, "pending": false, "permissions": "8", "communication_disabled_until": null, "flags": 0}
          },
          "channels": {
            "333": {"id": "333", "name": "Бункер", "type": 2, "permissions": "8", "parent_id": null}
          },
          "roles": {
            "555": {"id": "555", "name": "Выживший", "color": 0, "hoist": false, "icon": null, "unicode_emoji": null,
                    "position": 1, "permissions": "8", "managed": false, "mentionable": true, "flags": 0}
          },
          "attachments": {
            "666": {"id": "666", "filename": "map.png", "size": 1024, "url": "https://cdn.discordapp.com/map.png",
                    "proxy_url": "https://media.discordapp.net/map.png", "content_type": "image/png", "width": 64, "height": 64}
          }
        }
      }
    }
    """
}
