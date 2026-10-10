//
//  EntitySelectKind.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// What an ``EntitySelectMenu`` lets the user pick
public enum EntitySelectKind {
    case user
    case role
    case mentionable
    case channel

    var componentType: MessageComponentTypes {
        switch self {
        case .user: return .userSelect
        case .role: return .roleSelect
        case .mentionable: return .mentionableSelect
        case .channel: return .channelSelect
        }
    }
}
