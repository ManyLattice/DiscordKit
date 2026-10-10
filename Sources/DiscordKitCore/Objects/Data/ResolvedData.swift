//
//  ResolvedData.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation

/// Users, members, roles, channels and attachments referenced by interaction options, keyed by ID
public struct ResolvedData: Codable {

    public let users: [Snowflake: User]?
    public let members: [Snowflake: PartialMember]?
    public let roles: [Snowflake: Role]?
    public let channels: [Snowflake: Channel]?
    public let attachments: [Snowflake: Attachment]?
}
