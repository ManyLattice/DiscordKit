//
//  VoiceEvt.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public struct VoiceServerUpdate: GatewayData {
    public let token: String
    public let guild_id: Snowflake?
    public let endpoint: String?
    public let channel_id: Snowflake?

    public init(token: String, guild_id: Snowflake?, endpoint: String?, channel_id: Snowflake? = nil) {
        self.token = token
        self.guild_id = guild_id
        self.endpoint = endpoint
        self.channel_id = channel_id
    }
}
