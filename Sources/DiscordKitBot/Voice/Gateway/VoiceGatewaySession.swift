//
//  VoiceGatewaySession.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

public struct VoiceGatewaySession {

    //MARK: - Properties

    public enum State: Equatable {
        case connecting
        case identifying
        case discoveringIP
        case selectingProtocol
        case ready
        case resuming
        case closed
    }

    public static let supportedEncryptionMode = "aead_aes256_gcm_rtpsize"

    public let credentials: VoiceCredentials
    public let maxDaveProtocolVersion: Int
    public private(set) var state: State = .connecting
    public private(set) var sequenceAck = -1
    public private(set) var ready: VoiceGatewayIncoming.VoiceReady?
    public private(set) var connectedUserIDs: Set<Snowflake> = []

    //MARK: - Init

    public init(credentials: VoiceCredentials, maxDaveProtocolVersion: Int) {
        self.credentials = credentials
        self.maxDaveProtocolVersion = maxDaveProtocolVersion
    }

    //MARK: - Public methods

    public mutating func socketOpened() -> [VoiceGatewayAction] {
        switch state {
        case .connecting:
            state = .identifying
            return [.send(.identify(credentials, maxDaveProtocolVersion: maxDaveProtocolVersion))]
        case .resuming:
            return [.send(.resume(credentials, sequenceAck: sequenceAck))]
        default:
            return []
        }
    }

    public mutating func receive(_ message: VoiceGatewayIncoming, sequence: Int?) -> [VoiceGatewayAction] {
        guard state != .closed else { return [] }
        if let sequence {
            sequenceAck = sequence
        }

        switch message {
        case .hello(let interval):
            return [.startHeartbeat(interval: interval)]
        case .ready(let ready) where state == .identifying:
            guard ready.modes.contains(Self.supportedEncryptionMode) else {
                state = .closed
                return [.fail(.unsupportedEncryptionModes(ready.modes))]
            }
            self.ready = ready
            state = .discoveringIP
            return [.discoverIP(ready)]
        case .sessionDescription(let description) where state == .selectingProtocol:
            state = .ready
            return [.established(description)]
        case .resumed where state == .resuming:
            state = .ready
            return [.resumed]
        case .clientsConnect(let userIDs):
            connectedUserIDs.formUnion(userIDs)
            return []
        case .clientDisconnect(let userID):
            connectedUserIDs.remove(userID)
            return []
        case .davePrepareTransition, .daveExecuteTransition, .davePrepareEpoch,
             .daveExternalSender, .daveProposals, .daveAnnounceCommitTransition, .daveWelcome:
            return [.dave(message)]
        default:
            return []
        }
    }

    public mutating func ipDiscovered(address: String, port: UInt16) -> [VoiceGatewayAction] {
        guard state == .discoveringIP else { return [] }
        state = .selectingProtocol
        return [.send(.selectProtocol(address: address, port: port, mode: Self.supportedEncryptionMode))]
    }

    public mutating func ipDiscoveryFailed() -> [VoiceGatewayAction] {
        state = .closed
        return [.fail(.ipDiscoveryFailed)]
    }

    public mutating func socketClosed(code: Int) -> [VoiceGatewayAction] {
        guard state != .closed else { return [] }
        let canResume = code == 4015 || code < 4000
        if canResume && (state == .ready || state == .resuming) {
            state = .resuming
            return [.reconnectToResume]
        }
        state = .closed
        return [.fail(.closed(code: code))]
    }

    public func heartbeat(nonce: Int) -> VoiceGatewayOutgoing {
        .heartbeat(nonce: nonce, sequenceAck: sequenceAck)
    }

    public mutating func close() {
        state = .closed
    }
}
