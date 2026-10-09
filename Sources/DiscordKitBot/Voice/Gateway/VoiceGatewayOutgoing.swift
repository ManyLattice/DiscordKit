//
//  VoiceGatewayOutgoing.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

public enum VoiceGatewayOutgoing: Equatable {
    case identify(VoiceCredentials, maxDaveProtocolVersion: Int)
    case resume(VoiceCredentials, sequenceAck: Int)
    case selectProtocol(address: String, port: UInt16, mode: String)
    case heartbeat(nonce: Int, sequenceAck: Int)
    case speaking(Bool, ssrc: UInt32)
    case daveTransitionReady(transitionID: Int)
    case daveInvalidCommitWelcome(transitionID: Int)
    case daveKeyPackage(Data)
    case daveCommitWelcome(Data)

    public enum Frame: Equatable {
        case text(String)
        case binary(Data)
    }

    //MARK: - Public methods

    public func frame() throws -> Frame {
        switch self {
        case .daveKeyPackage(let payload):
            return .binary(Data([UInt8(VoiceOpcode.daveMLSKeyPackage.rawValue)]) + payload)
        case .daveCommitWelcome(let payload):
            return .binary(Data([UInt8(VoiceOpcode.daveMLSCommitWelcome.rawValue)]) + payload)
        default:
            let (opcode, data) = textPayload()
            let object: [String: Any] = ["op": opcode.rawValue, "d": data]
            let encoded = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return .text(String(decoding: encoded, as: UTF8.self))
        }
    }

    //MARK: - Private methods

    private func textPayload() -> (VoiceOpcode, Any) {
        switch self {
        case let .identify(credentials, maxDaveProtocolVersion):
            return (.identify, [
                "server_id": credentials.serverID,
                "user_id": credentials.userID,
                "session_id": credentials.sessionID,
                "token": credentials.token,
                "max_dave_protocol_version": maxDaveProtocolVersion
            ])
        case let .resume(credentials, sequenceAck):
            return (.resume, [
                "server_id": credentials.serverID,
                "session_id": credentials.sessionID,
                "token": credentials.token,
                "seq_ack": sequenceAck
            ])
        case let .selectProtocol(address, port, mode):
            return (.selectProtocol, [
                "protocol": "udp",
                "data": ["address": address, "port": Int(port), "mode": mode]
            ])
        case let .heartbeat(nonce, sequenceAck):
            return (.heartbeat, ["t": nonce, "seq_ack": sequenceAck])
        case let .speaking(isSpeaking, ssrc):
            return (.speaking, ["speaking": isSpeaking ? 1 : 0, "delay": 0, "ssrc": Int(ssrc)])
        case let .daveTransitionReady(transitionID):
            return (.daveTransitionReady, ["transition_id": transitionID])
        case let .daveInvalidCommitWelcome(transitionID):
            return (.daveMLSInvalidCommitWelcome, ["transition_id": transitionID])
        case .daveKeyPackage, .daveCommitWelcome:
            preconditionFailure("Binary DAVE messages have no text payload")
        }
    }
}
