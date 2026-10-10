//
//  MessageReactionEvt.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation

/// A reaction added to or removed from a message
public struct MessageReactionEvt: GatewayData {
    public let user_id: Snowflake
    public let channel_id: Snowflake
    public let message_id: Snowflake
    public let guild_id: Snowflake?
    /// The member who added the reaction, only on add in guilds
    public let member: Member?
    public let emoji: Emoji
    /// Author of the reacted message, only on add
    public let message_author_id: Snowflake?
    /// If this is a super reaction
    public let burst: Bool?
}
