//
//  EmbedBuilder.swift
//  
//
//  Created by Vincent Kwok on 16/12/22.
//

import Foundation
import DiscordKitCore

@resultBuilder
public struct EmbedBuilder {
    public static func buildBlock(_ components: [BotEmbed]...) -> [BotEmbed] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: BotEmbed) -> [BotEmbed] {
        [expression]
    }

    public static func buildArray(_ components: [[BotEmbed]]) -> [BotEmbed] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [BotEmbed]?) -> [BotEmbed] {
        component ?? []
    }

    public static func buildEither(first component: [BotEmbed]) -> [BotEmbed] {
        component
    }

    public static func buildEither(second component: [BotEmbed]) -> [BotEmbed] {
        component
    }
}
