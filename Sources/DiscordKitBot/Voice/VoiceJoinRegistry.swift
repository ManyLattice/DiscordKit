//
//  VoiceJoinRegistry.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

actor VoiceJoinRegistry {

    //MARK: - Properties

    private struct Pending {
        let id: UUID
        var handshake: VoiceHandshake
        let continuation: CheckedContinuation<VoiceConnectionInfo, Error>
    }

    private var pending: [Snowflake: Pending] = [:]

    //MARK: - Public methods

    func register(_ handshake: VoiceHandshake, id: UUID, continuation: CheckedContinuation<VoiceConnectionInfo, Error>) {
        pending.removeValue(forKey: handshake.guildID)?.continuation.resume(throwing: VoiceJoinError.superseded)
        pending[handshake.guildID] = Pending(id: id, handshake: handshake, continuation: continuation)
    }

    func receive(_ state: VoiceState) {
        guard let guildID = state.guild_id else { return }
        update(guildID: guildID) { $0.receive(state) }
    }

    func receive(_ update: VoiceServerUpdate) {
        guard let guildID = update.guild_id else { return }
        self.update(guildID: guildID) { $0.receive(update) }
    }

    func fail(guildID: Snowflake, id: UUID, error: VoiceJoinError) {
        guard pending[guildID]?.id == id else { return }
        pending.removeValue(forKey: guildID)?.continuation.resume(throwing: error)
    }

    func cancel(guildID: Snowflake) {
        pending.removeValue(forKey: guildID)?.continuation.resume(throwing: VoiceJoinError.superseded)
    }

    func hasPending(guildID: Snowflake) -> Bool {
        pending[guildID] != nil
    }

    //MARK: - Private methods

    private func update(guildID: Snowflake, _ apply: (inout VoiceHandshake) -> Void) {
        guard var entry = pending[guildID] else { return }
        apply(&entry.handshake)
        if let info = entry.handshake.info {
            pending.removeValue(forKey: guildID)
            entry.continuation.resume(returning: info)
        } else {
            pending[guildID] = entry
        }
    }
}
