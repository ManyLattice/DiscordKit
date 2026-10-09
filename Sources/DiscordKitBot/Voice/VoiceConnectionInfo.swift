//
//  VoiceConnectionInfo.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

public struct VoiceConnectionInfo: Equatable {
    public let guildID: Snowflake
    public let channelID: Snowflake
    public let userID: Snowflake
    public let sessionID: String
    public let token: String
    public let endpoint: String
}
