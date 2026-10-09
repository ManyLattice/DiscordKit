//
//  VoiceGatewayMessageTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitBot

final class VoiceGatewayMessageTests: XCTestCase {

    //MARK: - Tests

    func testDecodesHelloIntervalInSeconds() throws {
        let decoded = try VoiceGatewayIncoming.decode(text: #"{"op":8,"d":{"v":8,"heartbeat_interval":41250}}"#)

        XCTAssertEqual(decoded.message, .hello(heartbeatInterval: 41.25))
        XCTAssertNil(decoded.sequence)
    }

    func testDecodesReadyWithSequence() throws {
        let decoded = try VoiceGatewayIncoming.decode(text: """
        {"op":2,"seq":1,"d":{"ssrc":4027523361,"ip":"203.0.113.7","port":50001,
         "modes":["aead_aes256_gcm_rtpsize","aead_xchacha20_poly1305_rtpsize"],"heartbeat_interval":1}}
        """)

        guard case .ready(let ready) = decoded.message else { return XCTFail("Got \(decoded.message)") }
        XCTAssertEqual(ready.ssrc, 4_027_523_361)
        XCTAssertEqual(ready.ip, "203.0.113.7")
        XCTAssertEqual(ready.port, 50001)
        XCTAssertEqual(ready.modes.first, "aead_aes256_gcm_rtpsize")
        XCTAssertEqual(decoded.sequence, 1)
    }

    func testDecodesSessionDescription() throws {
        let key = Array(0..<32).map(String.init).joined(separator: ",")
        let decoded = try VoiceGatewayIncoming.decode(text: """
        {"op":4,"seq":2,"d":{"mode":"aead_aes256_gcm_rtpsize","secret_key":[\(key)],"dave_protocol_version":1}}
        """)

        XCTAssertEqual(decoded.message, .sessionDescription(.init(
            mode: "aead_aes256_gcm_rtpsize", secretKey: Array(0..<32), daveProtocolVersion: 1
        )))
    }

    func testSessionDescriptionWithoutDaveMeansVersionZero() throws {
        let decoded = try VoiceGatewayIncoming.decode(text: #"{"op":4,"d":{"mode":"aead_aes256_gcm_rtpsize","secret_key":[1,2]}}"#)

        guard case .sessionDescription(let description) = decoded.message else { return XCTFail("Got \(decoded.message)") }
        XCTAssertEqual(description.daveProtocolVersion, 0)
    }

    func testDecodesClientsAndDaveTextMessages() throws {
        XCTAssertEqual(try VoiceGatewayIncoming.decode(text: #"{"op":11,"d":{"user_ids":["1","2"]}}"#).message,
                       .clientsConnect(userIDs: ["1", "2"]))
        XCTAssertEqual(try VoiceGatewayIncoming.decode(text: #"{"op":13,"d":{"user_id":"2"}}"#).message,
                       .clientDisconnect(userID: "2"))
        XCTAssertEqual(try VoiceGatewayIncoming.decode(text: #"{"op":21,"d":{"transition_id":5,"protocol_version":0}}"#).message,
                       .davePrepareTransition(transitionID: 5, protocolVersion: 0))
        XCTAssertEqual(try VoiceGatewayIncoming.decode(text: #"{"op":22,"d":{"transition_id":5}}"#).message,
                       .daveExecuteTransition(transitionID: 5))
        XCTAssertEqual(try VoiceGatewayIncoming.decode(text: #"{"op":24,"d":{"epoch":1,"protocol_version":1}}"#).message,
                       .davePrepareEpoch(epoch: 1, protocolVersion: 1))
    }

    func testUnknownTextOpcodeIsNotAnError() throws {
        XCTAssertEqual(try VoiceGatewayIncoming.decode(text: #"{"op":18,"d":{"flags":2,"user_id":"1"}}"#).message,
                       .unknown(opcode: 18))
    }

    func testDecodesBinaryExternalSender() throws {
        let decoded = try VoiceGatewayIncoming.decode(binary: Data([0x01, 0x02, 25, 0xAA, 0xBB]))

        XCTAssertEqual(decoded.sequence, 258)
        XCTAssertEqual(decoded.message, .daveExternalSender(Data([0xAA, 0xBB])))
    }

    func testDecodesBinaryCommitAndWelcomeWithTransitionID() throws {
        XCTAssertEqual(try VoiceGatewayIncoming.decode(binary: Data([0x00, 0x07, 29, 0x00, 0x03, 0xC0, 0xFF])).message,
                       .daveAnnounceCommitTransition(transitionID: 3, commit: Data([0xC0, 0xFF])))
        XCTAssertEqual(try VoiceGatewayIncoming.decode(binary: Data([0x00, 0x08, 30, 0x01, 0x00, 0xEE])).message,
                       .daveWelcome(transitionID: 256, welcome: Data([0xEE])))
    }

    func testRejectsTruncatedBinaryFrames() {
        XCTAssertThrowsError(try VoiceGatewayIncoming.decode(binary: Data([0x00, 0x01])))
        XCTAssertThrowsError(try VoiceGatewayIncoming.decode(binary: Data([0x00, 0x01, 29, 0x00])))
    }

    func testEncodesIdentifyWithDaveVersion() throws {
        let object = try jsonObject(.identify(Self.credentials, maxDaveProtocolVersion: 1))
        let data = try XCTUnwrap(object["d"] as? [String: Any])

        XCTAssertEqual(object["op"] as? Int, 0)
        XCTAssertEqual(data["server_id"] as? String, "111")
        XCTAssertEqual(data["user_id"] as? String, "222")
        XCTAssertEqual(data["session_id"] as? String, "voice-session")
        XCTAssertEqual(data["token"] as? String, "voice-token")
        XCTAssertEqual(data["max_dave_protocol_version"] as? Int, 1)
    }

    func testEncodesHeartbeatWithSequenceAck() throws {
        let object = try jsonObject(.heartbeat(nonce: 1_501_184_119_561, sequenceAck: 10))

        XCTAssertEqual(object["op"] as? Int, 3)
        XCTAssertEqual(object["d"] as? [String: Int], ["t": 1_501_184_119_561, "seq_ack": 10])
    }

    func testEncodesSelectProtocolAndSpeaking() throws {
        let select = try jsonObject(.selectProtocol(address: "198.51.100.4", port: 61000, mode: "aead_aes256_gcm_rtpsize"))
        let selectData = try XCTUnwrap(select["d"] as? [String: Any])
        XCTAssertEqual(select["op"] as? Int, 1)
        XCTAssertEqual(selectData["protocol"] as? String, "udp")
        XCTAssertEqual(selectData["data"] as? [String: AnyHashable], ["address": "198.51.100.4", "port": 61000, "mode": "aead_aes256_gcm_rtpsize"])

        let speaking = try jsonObject(.speaking(true, ssrc: 4_027_523_361))
        XCTAssertEqual(speaking["op"] as? Int, 5)
        XCTAssertEqual(speaking["d"] as? [String: Int], ["speaking": 1, "delay": 0, "ssrc": 4_027_523_361])
    }

    func testEncodesBinaryDaveMessagesWithoutSequence() throws {
        XCTAssertEqual(try VoiceGatewayOutgoing.daveKeyPackage(Data([0x01, 0x02])).frame(), .binary(Data([26, 0x01, 0x02])))
        XCTAssertEqual(try VoiceGatewayOutgoing.daveCommitWelcome(Data([0x03])).frame(), .binary(Data([28, 0x03])))
    }

    func testEncodesResumeWithSequenceAck() throws {
        let object = try jsonObject(.resume(Self.credentials, sequenceAck: 42))
        let data = try XCTUnwrap(object["d"] as? [String: AnyHashable])

        XCTAssertEqual(object["op"] as? Int, 7)
        XCTAssertEqual(data, ["server_id": "111", "session_id": "voice-session", "token": "voice-token", "seq_ack": 42])
    }

    func testCredentialsURLUsesVersion8() {
        XCTAssertEqual(Self.credentials.url?.absoluteString, "wss://c-fra01.discord.media:443/?v=8")
    }

    //MARK: - Private methods

    static let credentials = VoiceCredentials(
        serverID: "111", userID: "222", sessionID: "voice-session", token: "voice-token", endpoint: "c-fra01.discord.media:443"
    )

    private func jsonObject(_ message: VoiceGatewayOutgoing) throws -> [String: Any] {
        guard case .text(let text) = try message.frame() else {
            XCTFail("Expected a text frame")
            return [:]
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }
}
