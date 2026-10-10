//
//  PartialMember.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation

/// A guild member as sent in interaction resolved data, without `user`, `deaf` and `mute`
public struct PartialMember: Codable {

    public let nick: String?
    public let avatar: String?
    public let roles: [Snowflake]
    public let joined_at: Date?
    public let premium_since: Date?
    public let pending: Bool?
    public let permissions: String?
    public let communication_disabled_until: Date?
}
