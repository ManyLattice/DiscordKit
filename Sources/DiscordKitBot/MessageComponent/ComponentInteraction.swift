//
//  ComponentInteraction.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// A click on a button or a pick in a select menu, with methods to respond to it
public class ComponentInteraction {

    //MARK: - Properties

    public typealias Handler = (_ interaction: ComponentInteraction) async -> Void

    public let customID: String
    public let componentType: MessageComponentTypes
    /// Values picked in a select menu, empty for buttons
    public let values: [String]
    /// Users, members, roles and channels picked in an entity select menu
    public let resolved: ResolvedData?
    /// The message the component is attached to
    public let message: Message?
    public let interactionID: Snowflake
    public let guildID: Snowflake?
    public let channelID: Snowflake?
    public let userID: Snowflake?

    private let responder: InteractionResponder

    //MARK: - Init

    init(
        data: Interaction.Data.MessageComponentData, interaction: Interaction,
        rest: DiscordREST, applicationID: String
    ) {
        self.customID = data.custom_id
        self.componentType = data.component_type
        self.values = data.values ?? []
        self.resolved = data.resolved
        self.message = interaction.message
        self.interactionID = interaction.id
        self.guildID = interaction.guildID
        self.channelID = interaction.channelID
        self.userID = interaction.member?.user?.id ?? interaction.user?.id
        self.responder = InteractionResponder(
            rest: rest, applicationID: applicationID, interactionID: interaction.id, token: interaction.token
        )
    }

    //MARK: - Public methods

    /// Reply with a new message, or a follow up if this interaction was already responded to
    public func reply(content: String?, embeds: [BotEmbed]? = nil, components: [Component]? = nil, ephemeral: Bool = false) async throws {
        try await responder.reply(content: content, embeds: embeds, components: components, ephemeral: ephemeral)
    }

    public func reply(_ content: String, ephemeral: Bool = false) async throws {
        try await reply(content: content, ephemeral: ephemeral)
    }

    /// Edit the message the component is attached to, `nil` keeps a field as is
    public func update(content: String? = nil, embeds: [BotEmbed]? = nil, components: [Component]? = nil) async throws {
        try await responder.respond(.updateMessage, data: .message(.init(content: content, embeds: embeds, components: components)))
    }

    /// Acknowledge the click without changing the message, e.g. before slow work
    public func deferUpdate() async throws {
        try await responder.respond(.deferredUpdateMessage, data: nil)
    }

    public func followUp(content: String?, embeds: [BotEmbed]? = nil, components: [Component]? = nil) async throws -> Message {
        try await responder.followUp(content: content, embeds: embeds, components: components)
    }

    /// Open a modal, only possible before any other response
    public func showModal(_ modal: Modal) async throws {
        try await responder.showModal(modal)
    }
}
