//
//  VoiceGatewayIncoming.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import DiscordKitCore

public enum VoiceGatewayIncoming: Equatable {
    case hello(heartbeatInterval: TimeInterval)
    case ready(VoiceReady)
    case sessionDescription(VoiceSessionDescription)
    case heartbeatAck
    case resumed
    case clientsConnect(userIDs: [Snowflake])
    case clientDisconnect(userID: Snowflake)
    case davePrepareTransition(transitionID: Int, protocolVersion: Int)
    case daveExecuteTransition(transitionID: Int)
    case davePrepareEpoch(epoch: Int, protocolVersion: Int)
    case daveExternalSender(Data)
    case daveProposals(Data)
    case daveAnnounceCommitTransition(transitionID: Int, commit: Data)
    case daveWelcome(transitionID: Int, welcome: Data)
    case unknown(opcode: Int)

    //MARK: - Payloads

    public struct VoiceReady: Decodable, Equatable {
        public let ssrc: UInt32
        public let ip: String
        public let port: UInt16
        public let modes: [String]
    }

    public struct VoiceSessionDescription: Decodable, Equatable {
        public let mode: String
        public let secretKey: [UInt8]
        public let daveProtocolVersion: Int

        enum CodingKeys: String, CodingKey {
            case mode
            case secretKey = "secret_key"
            case daveProtocolVersion = "dave_protocol_version"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            mode = try container.decode(String.self, forKey: .mode)
            secretKey = try container.decode([UInt8].self, forKey: .secretKey)
            daveProtocolVersion = try container.decodeIfPresent(Int.self, forKey: .daveProtocolVersion) ?? 0
        }

        public init(mode: String, secretKey: [UInt8], daveProtocolVersion: Int) {
            self.mode = mode
            self.secretKey = secretKey
            self.daveProtocolVersion = daveProtocolVersion
        }
    }

    //MARK: - Public methods

    public static func decode(text: String) throws -> (message: Self, sequence: Int?) {
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(text.utf8))
        return (envelope.message, envelope.sequence)
    }

    public static func decode(binary: Data) throws -> (message: Self, sequence: Int) {
        let bytes = [UInt8](binary)
        guard bytes.count >= 3 else { throw VoiceGatewayError.malformedBinaryFrame }
        let sequence = Int(bytes[0]) << 8 | Int(bytes[1])
        let opcode = Int(bytes[2])
        let payload = Data(bytes[3...])

        switch VoiceOpcode(rawValue: opcode) {
        case .daveMLSExternalSender:
            return (.daveExternalSender(payload), sequence)
        case .daveMLSProposals:
            return (.daveProposals(payload), sequence)
        case .daveMLSAnnounceCommitTransition:
            let (transitionID, rest) = try splitTransitionID(payload)
            return (.daveAnnounceCommitTransition(transitionID: transitionID, commit: rest), sequence)
        case .daveMLSWelcome:
            let (transitionID, rest) = try splitTransitionID(payload)
            return (.daveWelcome(transitionID: transitionID, welcome: rest), sequence)
        default:
            return (.unknown(opcode: opcode), sequence)
        }
    }

    //MARK: - Private methods

    private static func splitTransitionID(_ payload: Data) throws -> (Int, Data) {
        let bytes = [UInt8](payload)
        guard bytes.count >= 2 else { throw VoiceGatewayError.malformedBinaryFrame }
        return (Int(bytes[0]) << 8 | Int(bytes[1]), Data(bytes[2...]))
    }
}

private struct Envelope: Decodable {
    let message: VoiceGatewayIncoming
    let sequence: Int?

    enum CodingKeys: String, CodingKey {
        case op, d, seq
    }

    private struct Hello: Decodable { let heartbeat_interval: Double }
    private struct ClientsConnect: Decodable { let user_ids: [Snowflake] }
    private struct ClientDisconnect: Decodable { let user_id: Snowflake }
    private struct Transition: Decodable { let transition_id: Int; let protocol_version: Int? }
    private struct Epoch: Decodable { let epoch: Int; let protocol_version: Int }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sequence = try container.decodeIfPresent(Int.self, forKey: .seq)
        let opcode = try container.decode(Int.self, forKey: .op)

        switch VoiceOpcode(rawValue: opcode) {
        case .hello:
            let hello = try container.decode(Hello.self, forKey: .d)
            message = .hello(heartbeatInterval: hello.heartbeat_interval / 1000)
        case .ready:
            message = .ready(try container.decode(VoiceGatewayIncoming.VoiceReady.self, forKey: .d))
        case .sessionDescription:
            message = .sessionDescription(try container.decode(VoiceGatewayIncoming.VoiceSessionDescription.self, forKey: .d))
        case .heartbeatAck:
            message = .heartbeatAck
        case .resumed:
            message = .resumed
        case .clientsConnect:
            message = .clientsConnect(userIDs: try container.decode(ClientsConnect.self, forKey: .d).user_ids)
        case .clientDisconnect:
            message = .clientDisconnect(userID: try container.decode(ClientDisconnect.self, forKey: .d).user_id)
        case .davePrepareTransition:
            let transition = try container.decode(Transition.self, forKey: .d)
            message = .davePrepareTransition(transitionID: transition.transition_id, protocolVersion: transition.protocol_version ?? 0)
        case .daveExecuteTransition:
            message = .daveExecuteTransition(transitionID: try container.decode(Transition.self, forKey: .d).transition_id)
        case .davePrepareEpoch:
            let epoch = try container.decode(Epoch.self, forKey: .d)
            message = .davePrepareEpoch(epoch: epoch.epoch, protocolVersion: epoch.protocol_version)
        default:
            message = .unknown(opcode: opcode)
        }
    }
}
