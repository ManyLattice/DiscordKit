//
//  DAVECoordinator.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

public struct DAVECoordinator {

    //MARK: - Properties

    public private(set) var protocolVersion: Int
    public private(set) var pendingTransitions: [Int: Int] = [:]

    private let crypto: DAVECrypto
    private let groupID: UInt64
    private let selfUserID: Snowflake
    private var reinitializing = false

    //MARK: - Init

    public init(crypto: DAVECrypto, protocolVersion: Int, channelID: Snowflake, selfUserID: Snowflake) {
        self.crypto = crypto
        self.protocolVersion = protocolVersion
        self.groupID = UInt64(channelID) ?? 0
        self.selfUserID = selfUserID
    }

    //MARK: - Public methods

    public mutating func start() -> [VoiceGatewayOutgoing] {
        reinit()
    }

    public mutating func handle(_ message: VoiceGatewayIncoming, connectedUserIDs: Set<Snowflake>) -> [VoiceGatewayOutgoing] {
        // libdave validates every roster member of a welcome, including this bot.
        let recognized = connectedUserIDs.union([selfUserID])

        switch message {
        case .daveExternalSender(let externalSender):
            crypto.setExternalSender(externalSender)
            return []
        case .daveProposals(let payload):
            guard let commitWelcome = crypto.processProposals(payload, recognizedUserIDs: recognized) else { return [] }
            return [.daveCommitWelcome(commitWelcome)]
        case let .daveAnnounceCommitTransition(transitionID, commit):
            switch crypto.processCommit(commit) {
            case .accepted: return accepted(transitionID: transitionID)
            case .ignored: return []
            case .failed: return recover(transitionID: transitionID)
            }
        case let .daveWelcome(transitionID, welcome):
            guard crypto.processWelcome(welcome, recognizedUserIDs: recognized) else {
                return recover(transitionID: transitionID)
            }
            return accepted(transitionID: transitionID)
        case let .davePrepareTransition(transitionID, version):
            pendingTransitions[transitionID] = version
            if transitionID == 0 {
                execute(transitionID: 0)
                return []
            }
            return [.daveTransitionReady(transitionID: transitionID)]
        case .daveExecuteTransition(let transitionID):
            execute(transitionID: transitionID)
            return []
        case let .davePrepareEpoch(epoch, version):
            guard epoch == 1 else { return [] }
            protocolVersion = version
            return reinit()
        default:
            return []
        }
    }

    public func encrypt(_ frame: Data, ssrc: UInt32) -> Data {
        guard protocolVersion > 0, frame != RTPPacketizer.silenceFrame else { return frame }
        return crypto.encrypt(frame, ssrc: ssrc) ?? frame
    }

    //MARK: - Private methods

    private mutating func reinit() -> [VoiceGatewayOutgoing] {
        guard protocolVersion > 0 else {
            crypto.reset()
            crypto.setPassthrough(true)
            return []
        }
        crypto.reinit(protocolVersion: protocolVersion, groupID: groupID, selfUserID: selfUserID)
        return [.daveKeyPackage(crypto.keyPackage())]
    }

    private mutating func accepted(transitionID: Int) -> [VoiceGatewayOutgoing] {
        reinitializing = false
        if transitionID == 0 {
            switchSenderToLatestKeys()
            return []
        }
        pendingTransitions[transitionID] = protocolVersion
        return [.daveTransitionReady(transitionID: transitionID)]
    }

    // Senders must keep the old keys until the server executes the transition.
    private mutating func execute(transitionID: Int) {
        guard let version = pendingTransitions.removeValue(forKey: transitionID) else { return }
        protocolVersion = version
        if version == 0 {
            crypto.setPassthrough(true)
        } else {
            switchSenderToLatestKeys()
        }
    }

    private func switchSenderToLatestKeys() {
        crypto.useLatestKeyRatchet()
        crypto.setPassthrough(false)
    }

    private mutating func recover(transitionID: Int) -> [VoiceGatewayOutgoing] {
        guard !reinitializing else { return [] }
        reinitializing = true
        return [.daveInvalidCommitWelcome(transitionID: transitionID)] + reinit()
    }
}
