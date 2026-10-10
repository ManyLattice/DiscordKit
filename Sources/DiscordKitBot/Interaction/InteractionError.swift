//
//  InteractionError.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

public enum InteractionError: Error {
    /// The ``Client`` that received the interaction was deallocated
    case clientGone
    /// Discord only accepts a modal as the first response to an interaction
    case modalAfterResponse
}
