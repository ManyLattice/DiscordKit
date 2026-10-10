//
//  EmbedFieldBuilder.swift
//  
//
//  Created by Vincent Kwok on 16/12/22.
//

import Foundation

@resultBuilder
public struct EmbedFieldBuilder {
    public static func buildBlock(_ components: [BotEmbed.Field]...) -> [BotEmbed.Field] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: BotEmbed.Field) -> [BotEmbed.Field] {
        [expression]
    }

    public static func buildArray(_ components: [[BotEmbed.Field]]) -> [BotEmbed.Field] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [BotEmbed.Field]?) -> [BotEmbed.Field] {
        component ?? []
    }

    public static func buildEither(first component: [BotEmbed.Field]) -> [BotEmbed.Field] {
        component
    }

    public static func buildEither(second component: [BotEmbed.Field]) -> [BotEmbed.Field] {
        component
    }
}
