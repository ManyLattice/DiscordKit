//
//  VoiceCredentials.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

public struct VoiceCredentials: Equatable {
    public let serverID: Snowflake
    public let userID: Snowflake
    public let sessionID: String
    public let token: String
    public let endpoint: String

    public init(serverID: Snowflake, userID: Snowflake, sessionID: String, token: String, endpoint: String) {
        self.serverID = serverID
        self.userID = userID
        self.sessionID = sessionID
        self.token = token
        self.endpoint = endpoint
    }

    public init(_ info: VoiceConnectionInfo) {
        self.init(serverID: info.guildID, userID: info.userID, sessionID: info.sessionID, token: info.token, endpoint: info.endpoint)
    }

    public var url: URL? {
        URL(string: "wss://\(endpoint)/?v=8")
    }
}
