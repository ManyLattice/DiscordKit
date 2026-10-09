//
//  VoiceHandshake.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

struct VoiceHandshake {

    //MARK: - Properties

    let guildID: Snowflake
    let userID: Snowflake
    private var channelID: Snowflake
    private var sessionID: String?
    private var token: String?
    private var endpoint: String?

    var info: VoiceConnectionInfo? {
        guard let sessionID, let token, let endpoint else { return nil }
        return VoiceConnectionInfo(
            guildID: guildID,
            channelID: channelID,
            userID: userID,
            sessionID: sessionID,
            token: token,
            endpoint: endpoint
        )
    }

    //MARK: - Init

    init(guildID: Snowflake, channelID: Snowflake, userID: Snowflake) {
        self.guildID = guildID
        self.channelID = channelID
        self.userID = userID
    }

    //MARK: - Public methods

    mutating func receive(_ state: VoiceState) {
        guard state.user_id == userID, state.guild_id == guildID, let channelID = state.channel_id else { return }
        self.channelID = channelID
        sessionID = state.session_id
    }

    mutating func receive(_ update: VoiceServerUpdate) {
        guard update.guild_id == guildID, let endpoint = update.endpoint else { return }
        token = update.token
        self.endpoint = endpoint
    }
}
