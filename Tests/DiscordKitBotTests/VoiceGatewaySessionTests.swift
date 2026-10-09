//
//  VoiceGatewaySessionTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitBot

final class VoiceGatewaySessionTests: XCTestCase {

    //MARK: - Tests

    func testFullHandshakeReachesReady() {
        var session = makeSession()

        XCTAssertEqual(session.socketOpened(), [.send(.identify(VoiceGatewayMessageTests.credentials, maxDaveProtocolVersion: 1))])
        XCTAssertEqual(session.receive(.hello(heartbeatInterval: 41.25), sequence: nil), [.startHeartbeat(interval: 41.25)])
        XCTAssertEqual(session.receive(.ready(Self.ready), sequence: 1), [.discoverIP(Self.ready)])
        XCTAssertEqual(session.state, .discoveringIP)
        XCTAssertEqual(session.ipDiscovered(address: "198.51.100.4", port: 61000),
                       [.send(.selectProtocol(address: "198.51.100.4", port: 61000, mode: "aead_aes256_gcm_rtpsize"))])
        XCTAssertEqual(session.receive(.sessionDescription(Self.description), sequence: 2), [.established(Self.description)])
        XCTAssertEqual(session.state, .ready)
        XCTAssertEqual(session.sequenceAck, 2)
    }

    func testHeartbeatCarriesLastSequenceFromTextAndBinaryFrames() {
        var session = readySession()
        XCTAssertEqual(session.heartbeat(nonce: 7), .heartbeat(nonce: 7, sequenceAck: 2))

        _ = session.receive(.daveExternalSender(Data([0x01])), sequence: 9)

        XCTAssertEqual(session.heartbeat(nonce: 8), .heartbeat(nonce: 8, sequenceAck: 9))
    }

    func testHeartbeatBeforeAnySequenceSendsMinusOne() {
        XCTAssertEqual(makeSession().heartbeat(nonce: 1), .heartbeat(nonce: 1, sequenceAck: -1))
    }

    func testResumableCloseReconnectsAndResumes() {
        var session = readySession()

        XCTAssertEqual(session.socketClosed(code: 4015), [.reconnectToResume])
        XCTAssertEqual(session.socketOpened(), [.send(.resume(VoiceGatewayMessageTests.credentials, sequenceAck: 2))])
        XCTAssertEqual(session.receive(.resumed, sequence: nil), [.resumed])
        XCTAssertEqual(session.state, .ready)
    }

    func testNetworkCloseIsResumable() {
        var session = readySession()

        XCTAssertEqual(session.socketClosed(code: 1006), [.reconnectToResume])
    }

    func testDisconnectCloseFails() {
        var session = readySession()

        XCTAssertEqual(session.socketClosed(code: 4014), [.fail(.closed(code: 4014))])
        XCTAssertEqual(session.state, .closed)
        XCTAssertEqual(session.receive(.hello(heartbeatInterval: 1), sequence: nil), [])
    }

    func testCloseBeforeReadyFailsEvenIfResumable() {
        var session = makeSession()
        _ = session.socketOpened()

        XCTAssertEqual(session.socketClosed(code: 1006), [.fail(.closed(code: 1006))])
    }

    func testReadyWithoutSupportedModeFails() {
        var session = makeSession()
        _ = session.socketOpened()
        let ready = VoiceGatewayIncoming.VoiceReady(ssrc: 1, ip: "203.0.113.7", port: 1, modes: ["aead_xchacha20_poly1305_rtpsize"])

        XCTAssertEqual(session.receive(.ready(ready), sequence: nil), [.fail(.unsupportedEncryptionModes(["aead_xchacha20_poly1305_rtpsize"]))])
        XCTAssertEqual(session.state, .closed)
    }

    func testIgnoresOutOfOrderMessages() {
        var session = makeSession()
        _ = session.socketOpened()

        XCTAssertEqual(session.receive(.sessionDescription(Self.description), sequence: nil), [])
        XCTAssertEqual(session.ipDiscovered(address: "198.51.100.4", port: 1), [])
        XCTAssertEqual(session.state, .identifying)
    }

    func testTracksConnectedUsers() {
        var session = readySession()

        _ = session.receive(.clientsConnect(userIDs: ["1", "2", "3"]), sequence: 3)
        _ = session.receive(.clientDisconnect(userID: "2"), sequence: 4)

        XCTAssertEqual(session.connectedUserIDs, ["1", "3"])
    }

    func testForwardsDaveMessages() {
        var session = readySession()
        let message = VoiceGatewayIncoming.davePrepareEpoch(epoch: 1, protocolVersion: 1)

        XCTAssertEqual(session.receive(message, sequence: 3), [.dave(message)])
    }

    func testIPDiscoveryFailureFails() {
        var session = makeSession()
        _ = session.socketOpened()
        _ = session.receive(.ready(Self.ready), sequence: nil)

        XCTAssertEqual(session.ipDiscoveryFailed(), [.fail(.ipDiscoveryFailed)])
    }

    //MARK: - Private methods

    private static let ready = VoiceGatewayIncoming.VoiceReady(
        ssrc: 4_027_523_361, ip: "203.0.113.7", port: 50001, modes: ["aead_aes256_gcm_rtpsize", "aead_xchacha20_poly1305_rtpsize"]
    )
    private static let description = VoiceGatewayIncoming.VoiceSessionDescription(
        mode: "aead_aes256_gcm_rtpsize", secretKey: Array(repeating: 7, count: 32), daveProtocolVersion: 1
    )

    private func makeSession() -> VoiceGatewaySession {
        VoiceGatewaySession(credentials: VoiceGatewayMessageTests.credentials, maxDaveProtocolVersion: 1)
    }

    private func readySession() -> VoiceGatewaySession {
        var session = makeSession()
        _ = session.socketOpened()
        _ = session.receive(.ready(Self.ready), sequence: 1)
        _ = session.ipDiscovered(address: "198.51.100.4", port: 61000)
        _ = session.receive(.sessionDescription(Self.description), sequence: 2)
        return session
    }
}
