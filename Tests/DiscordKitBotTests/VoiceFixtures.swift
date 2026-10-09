//
//  VoiceFixtures.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore
@testable import DiscordKitBot

enum VoiceFixtures {

    //MARK: - Properties

    static let expectedInfo = VoiceConnectionInfo(
        guildID: "111",
        channelID: "333",
        userID: "222",
        sessionID: "voice-session",
        token: "voice-token",
        endpoint: "c-fra01.discord.media:443"
    )

    //MARK: - Public methods

    static func state(guildID: Snowflake = "111", channelID: Snowflake? = "333", userID: Snowflake = "222") -> VoiceState {
        let channel = channelID.map { "\"\($0)\"" } ?? "null"
        return decode("""
        {"guild_id":"\(guildID)","channel_id":\(channel),"user_id":"\(userID)","session_id":"voice-session",
         "deaf":false,"mute":false,"self_deaf":true,"self_mute":false,"self_video":false,"suppress":false,
         "request_to_speak_timestamp":null}
        """)
    }

    static func server(guildID: Snowflake = "111", endpoint: String? = "c-fra01.discord.media:443") -> VoiceServerUpdate {
        VoiceServerUpdate(token: "voice-token", guild_id: guildID, endpoint: endpoint)
    }

    //MARK: - Private methods

    private static func decode(_ json: String) -> VoiceState {
        do {
            return try DiscordREST.decoder.decode(VoiceState.self, from: Data(json.utf8))
        } catch {
            preconditionFailure("Invalid voice state fixture: \(error)")
        }
    }
}
