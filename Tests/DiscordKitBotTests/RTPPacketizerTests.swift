//
//  RTPPacketizerTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitBot

final class RTPPacketizerTests: XCTestCase {

    //MARK: - Tests

    // Expected bytes come from Node's crypto using the same algorithm as @discordjs/voice.
    func testMatchesReferencePacketsAndWrapsCounters() throws {
        var packetizer = RTPPacketizer(
            ssrc: 4_027_523_361,
            secretKey: Array(0..<32),
            sequence: 65535,
            timestamp: 4_294_966_336,
            nonce: 0
        )
        let opus = Data([0xFC, 0xFF, 0xFE, 0x01, 0x02, 0x03])

        XCTAssertEqual(try packetizer.packet(for: opus).hex,
                       "8078fffffffffc40f00f2121f2434bdfb72f9467ef6eda6df878f0a5b76abe8013d000000000")
        XCTAssertEqual(try packetizer.packet(for: opus).hex,
                       "8078000000000000f00f2121b8c933ab0e59c4f2decca9f9800f408c247b4c668b6600000001")
        XCTAssertEqual(packetizer.sequence, 1)
        XCTAssertEqual(packetizer.timestamp, 960)
        XCTAssertEqual(packetizer.nonce, 2)
    }

    func testPacketLengthIsHeaderPayloadTagAndNonce() throws {
        var packetizer = RTPPacketizer(ssrc: 1, secretKey: Array(repeating: 9, count: 32))

        XCTAssertEqual(try packetizer.packet(for: Data(count: 100)).count, 12 + 100 + 16 + 4)
    }
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
