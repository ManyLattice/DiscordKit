//
//  GatewayReactionMemberEventTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitCore

final class GatewayReactionMemberEventTests: XCTestCase {

    //MARK: - Tests

    func testReactionAddDecodesMemberAndUnicodeEmoji() throws {
        let incoming = try decode("""
        {"op":0,"s":10,"t":"MESSAGE_REACTION_ADD","d":{
          "user_id":"444","channel_id":"222","message_id":"800","guild_id":"111","message_author_id":"100",
          "burst":false,"burst_colors":[],"type":0,
          "member":{"user":{"id":"444","username":"player","discriminator":"0","avatar":null},
                    "roles":[],"joined_at":"2023-10-15T10:00:00.123000+00:00","deaf":false,"mute":false},
          "emoji":{"id":null,"name":"👍"}
        }}
        """)

        guard case .messageReactionAdd(let reaction) = incoming.data else {
            return XCTFail("Expected reaction add, got \(incoming.data)")
        }
        XCTAssertEqual(reaction.user_id, "444")
        XCTAssertEqual(reaction.message_id, "800")
        XCTAssertEqual(reaction.message_author_id, "100")
        XCTAssertEqual(reaction.member?.user?.username, "player")
        XCTAssertNil(reaction.emoji.id)
        XCTAssertEqual(reaction.emoji.name, "👍")
    }

    func testReactionRemoveDecodesCustomEmojiWithoutMember() throws {
        let incoming = try decode("""
        {"op":0,"s":11,"t":"MESSAGE_REACTION_REMOVE","d":{
          "user_id":"444","channel_id":"222","message_id":"800","guild_id":"111","burst":false,"type":0,
          "emoji":{"id":"999","name":"bunker","animated":false}
        }}
        """)

        guard case .messageReactionRemove(let reaction) = incoming.data else {
            return XCTFail("Expected reaction remove, got \(incoming.data)")
        }
        XCTAssertNil(reaction.member)
        XCTAssertEqual(reaction.emoji.id, "999")
        XCTAssertEqual(reaction.emoji.name, "bunker")
    }

    func testMemberAddDecodesGuild() throws {
        let incoming = try decode("""
        {"op":0,"s":12,"t":"GUILD_MEMBER_ADD","d":{
          "guild_id":"111","user":{"id":"555","username":"newbie","discriminator":"0","avatar":null},
          "roles":[],"joined_at":"2026-10-10T07:00:00.000000+00:00","deaf":false,"mute":false,"pending":false,"flags":0
        }}
        """)

        guard case .guildMemberAdd(let member) = incoming.data else {
            return XCTFail("Expected member add, got \(incoming.data)")
        }
        XCTAssertEqual(member.guild_id, "111")
        XCTAssertEqual(member.user?.username, "newbie")
    }

    func testMemberRemoveDecodesUser() throws {
        let incoming = try decode("""
        {"op":0,"s":13,"t":"GUILD_MEMBER_REMOVE","d":{
          "guild_id":"111","user":{"id":"555","username":"newbie","discriminator":"0","avatar":null}
        }}
        """)

        guard case .guildMemberRemove(let removal) = incoming.data else {
            return XCTFail("Expected member remove, got \(incoming.data)")
        }
        XCTAssertEqual(removal.guild_id, "111")
        XCTAssertEqual(removal.user.id, "555")
    }

    func testAutoModIntentsHaveDistinctBits() {
        XCTAssertEqual(Intents.autoModCfg.rawValue, 1 << 20)
        XCTAssertEqual(Intents.autoModExec.rawValue, 1 << 21)
    }

    //MARK: - Private methods

    private func decode(_ json: String) throws -> GatewayIncoming {
        try DiscordREST.decoder.decode(GatewayIncoming.self, from: Data(json.utf8))
    }
}
