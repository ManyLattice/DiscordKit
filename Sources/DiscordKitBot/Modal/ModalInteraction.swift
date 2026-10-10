//
//  ModalInteraction.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// A submitted modal, with the entered text and methods to respond
public class ModalInteraction {

    //MARK: - Properties

    public typealias Handler = (_ interaction: ModalInteraction) async -> Void

    public let customID: String
    /// Text the user entered, keyed by ``TextInput`` ID
    public let values: [String: String]
    /// The message whose component opened the modal, `nil` if a command opened it
    public let message: Message?
    public let interactionID: Snowflake
    public let guildID: Snowflake?
    public let channelID: Snowflake?
    public let userID: Snowflake?

    private let responder: InteractionResponder

    //MARK: - Init

    init(data: ModalSubmitData, interaction: Interaction, rest: DiscordREST, applicationID: String) {
        self.customID = data.custom_id
        self.values = data.values
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

    public func value(of inputID: String) -> String? {
        values[inputID]
    }

    /// Reply with a new message, or a follow up if this interaction was already responded to
    public func reply(content: String?, embeds: [BotEmbed]? = nil, components: [Component]? = nil, ephemeral: Bool = false) async throws {
        try await responder.reply(content: content, embeds: embeds, components: components, ephemeral: ephemeral)
    }

    public func reply(_ content: String, ephemeral: Bool = false) async throws {
        try await reply(content: content, ephemeral: ephemeral)
    }

    /// Edit the message whose component opened the modal, `nil` keeps a field as is
    public func update(content: String? = nil, embeds: [BotEmbed]? = nil, components: [Component]? = nil) async throws {
        try await responder.respond(.updateMessage, data: .message(.init(content: content, embeds: embeds, components: components)))
    }

    public func followUp(content: String?, embeds: [BotEmbed]? = nil, components: [Component]? = nil) async throws -> Message {
        try await responder.followUp(content: content, embeds: embeds, components: components)
    }
}
