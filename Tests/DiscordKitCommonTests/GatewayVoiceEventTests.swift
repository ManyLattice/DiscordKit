//
//  GatewayVoiceEventTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitCore

final class GatewayVoiceEventTests: XCTestCase {

    //MARK: - Tests

    func testVoiceStateUpdateWithMemberDecodes() throws {
        let incoming = try decode("""
        {"op":0,"s":45,"t":"VOICE_STATE_UPDATE","d":{
          "member":{
            "user":{"username":"bunker","public_flags":0,"id":"222","global_name":null,"discriminator":"0","avatar":null,"bot":true},
            "roles":["777"],"premium_since":null,"pending":false,"nick":null,"mute":false,
            "joined_at":"2023-10-15T10:00:00.123000+00:00","flags":0,"deaf":false,"communication_disabled_until":null,"avatar":null
          },
          "user_id":"222","suppress":false,"session_id":"voice-session","self_video":false,"self_mute":false,
          "self_deaf":true,"request_to_speak_timestamp":null,"mute":false,"guild_id":"111","deaf":false,"channel_id":"333"
        }}
        """)

        guard case .voiceStateUpdate(let state) = incoming.data else {
            return XCTFail("Expected voice state update, got \(incoming.data)")
        }
        XCTAssertEqual(state.guild_id, "111")
        XCTAssertEqual(state.channel_id, "333")
        XCTAssertEqual(state.user_id, "222")
        XCTAssertEqual(state.session_id, "voice-session")
        XCTAssertEqual(state.member?.roles, ["777"])
    }

    func testVoiceServerUpdateDecodes() throws {
        let incoming = try decode("""
        {"op":0,"s":46,"t":"VOICE_SERVER_UPDATE","d":{"token":"voice-token","guild_id":"111","endpoint":"c-fra01.discord.media:443"}}
        """)

        guard case .voiceServerUpdate(let update) = incoming.data else {
            return XCTFail("Expected voice server update, got \(incoming.data)")
        }
        XCTAssertEqual(update.token, "voice-token")
        XCTAssertEqual(update.guild_id, "111")
        XCTAssertEqual(update.endpoint, "c-fra01.discord.media:443")
    }

    func testVoiceServerUpdateWithNullEndpointDecodes() throws {
        let incoming = try decode("""
        {"op":0,"s":47,"t":"VOICE_SERVER_UPDATE","d":{"token":"voice-token","guild_id":"111","endpoint":null}}
        """)

        guard case .voiceServerUpdate(let update) = incoming.data else {
            return XCTFail("Expected voice server update, got \(incoming.data)")
        }
        XCTAssertNil(update.endpoint)
    }

    func testLeaveVoicePayloadEncodesNullChannel() throws {
        let payload = GatewayOutgoing(
            opcode: .voiceStateUpdate,
            data: GatewayVoiceStateUpdate(guild_id: "111", channel_id: nil, self_mute: false, self_deaf: false, self_video: nil),
            seq: nil
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(payload)) as? [String: Any])
        let data = try XCTUnwrap(object["d"] as? [String: Any])

        XCTAssertEqual(object["op"] as? Int, 4)
        XCTAssertEqual(data["guild_id"] as? String, "111")
        XCTAssertTrue(data["channel_id"] is NSNull)
    }

    //MARK: - Private methods

    private func decode(_ json: String) throws -> GatewayIncoming {
        try DiscordREST.decoder.decode(GatewayIncoming.self, from: Data(json.utf8))
    }
}
