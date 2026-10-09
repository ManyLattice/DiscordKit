//
//  VoiceHandshakeTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
import DiscordKitCore
@testable import DiscordKitBot

final class VoiceHandshakeTests: XCTestCase {

    //MARK: - Tests

    func testStateThenServerProducesInfo() {
        var handshake = makeHandshake()
        handshake.receive(VoiceFixtures.state())
        XCTAssertNil(handshake.info)

        handshake.receive(VoiceFixtures.server())

        XCTAssertEqual(handshake.info, VoiceFixtures.expectedInfo)
    }

    func testServerThenStateProducesInfo() {
        var handshake = makeHandshake()
        handshake.receive(VoiceFixtures.server())
        XCTAssertNil(handshake.info)

        handshake.receive(VoiceFixtures.state())

        XCTAssertEqual(handshake.info, VoiceFixtures.expectedInfo)
    }

    func testIgnoresOtherUsersAndGuilds() {
        var handshake = makeHandshake()
        handshake.receive(VoiceFixtures.state(userID: "someone-else"))
        handshake.receive(VoiceFixtures.state(guildID: "other-guild"))
        handshake.receive(VoiceFixtures.server(guildID: "other-guild"))

        XCTAssertNil(handshake.info)
    }

    func testWaitsForServerWithEndpoint() {
        var handshake = makeHandshake()
        handshake.receive(VoiceFixtures.state())
        handshake.receive(VoiceFixtures.server(endpoint: nil))
        XCTAssertNil(handshake.info)

        handshake.receive(VoiceFixtures.server())

        XCTAssertEqual(handshake.info, VoiceFixtures.expectedInfo)
    }

    func testIgnoresDisconnectState() {
        var handshake = makeHandshake()
        handshake.receive(VoiceFixtures.state(channelID: nil))
        handshake.receive(VoiceFixtures.server())

        XCTAssertNil(handshake.info)
    }

    func testUsesChannelReportedByDiscord() {
        var handshake = makeHandshake()
        handshake.receive(VoiceFixtures.state(channelID: "moved-channel"))
        handshake.receive(VoiceFixtures.server())

        XCTAssertEqual(handshake.info?.channelID, "moved-channel")
    }

    //MARK: - Private methods

    private func makeHandshake() -> VoiceHandshake {
        VoiceHandshake(guildID: "111", channelID: "333", userID: "222")
    }
}
