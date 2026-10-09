//
//  APIVoice.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

public extension DiscordREST {
    /// Get a user's voice state in a guild
    ///
    /// > GET: `/guilds/{guild.id}/voice-states/{user.id}`
    ///
    /// Returns `nil` when the user is not connected to a voice channel in the guild.
    func getVoiceState(guildID: Snowflake, userID: Snowflake) async throws -> VoiceState? {
        do {
            return try await getReq(path: "guilds/\(guildID)/voice-states/\(userID)")
        } catch RequestError.unexpectedResponseCode(404) {
            return nil
        }
    }
}
