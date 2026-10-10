//
//  InteractionResponder.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// Sends the initial response and follow ups for one interaction
final class InteractionResponder {

    //MARK: - Properties

    private(set) var hasResponded = false

    private weak var rest: DiscordREST?
    private let applicationID: String
    private let interactionID: Snowflake
    private let token: String

    //MARK: - Init

    init(rest: DiscordREST, applicationID: String, interactionID: Snowflake, token: String) {
        self.rest = rest
        self.applicationID = applicationID
        self.interactionID = interactionID
        self.token = token
    }

    //MARK: - Public methods

    func respond(_ type: InteractionResponse.ResponseType, data: InteractionResponse.ResponseData?) async throws {
        guard let rest else { throw InteractionError.clientGone }
        try await rest.sendInteractionResponse(.init(type: type, data: data), interactionID: interactionID, token: token)
        hasResponded = true
    }

    func reply(content: String?, embeds: [BotEmbed]?, components: [Component]?, ephemeral: Bool) async throws {
        if hasResponded {
            _ = try await followUp(content: content, embeds: embeds, components: components)
            return
        }
        try await respond(
            .interactionReply,
            data: .message(.init(content: content, embeds: embeds, flags: ephemeral ? .ephemeral : nil, components: components))
        )
    }

    func followUp(content: String?, embeds: [BotEmbed]?, components: [Component]?) async throws -> Message {
        guard let rest else { throw InteractionError.clientGone }
        return try await rest.sendInteractionFollowUp(
            .init(content: content, embeds: embeds, components: components),
            applicationID: applicationID, token: token
        )
    }

    func showModal(_ modal: Modal) async throws {
        guard !hasResponded else { throw InteractionError.modalAfterResponse }
        try await respond(.modal, data: .modal(modal))
    }
}
