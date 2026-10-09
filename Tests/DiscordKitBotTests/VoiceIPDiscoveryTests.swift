//
//  VoiceIPDiscoveryTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitBot

final class VoiceIPDiscoveryTests: XCTestCase {

    //MARK: - Tests

    func testRequestLayout() {
        let request = VoiceIPDiscovery.request(ssrc: 0x0102_0304)

        XCTAssertEqual(request.count, 74)
        XCTAssertEqual(Array(request.prefix(8)), [0x00, 0x01, 0x00, 70, 0x01, 0x02, 0x03, 0x04])
        XCTAssertTrue(request.dropFirst(8).allSatisfy { $0 == 0 })
    }

    func testParsesResponse() throws {
        let response = try XCTUnwrap(VoiceIPDiscovery.parseResponse(VoiceIPDiscoveryTests.response(address: "198.51.100.4", port: 61000)))

        XCTAssertEqual(response.address, "198.51.100.4")
        XCTAssertEqual(response.port, 61000)
    }

    func testRejectsRequestsAndTruncatedPackets() {
        XCTAssertNil(VoiceIPDiscovery.parseResponse(VoiceIPDiscovery.request(ssrc: 1)))
        XCTAssertNil(VoiceIPDiscovery.parseResponse(Data([0x00, 0x02, 0x00, 70])))
        XCTAssertNil(VoiceIPDiscovery.parseResponse(VoiceIPDiscoveryTests.response(address: "", port: 1)))
    }

    //MARK: - Public methods

    static func response(address: String, port: UInt16, ssrc: UInt32 = 1) -> Data {
        var packet = Data([0x00, 0x02, 0x00, 70])
        packet.append(contentsOf: withUnsafeBytes(of: ssrc.bigEndian) { Array($0) })
        var addressField = Array(address.utf8)
        addressField += Array(repeating: 0, count: 64 - addressField.count)
        packet.append(contentsOf: addressField)
        packet.append(contentsOf: [UInt8(port >> 8), UInt8(port & 0xFF)])
        return packet
    }
}
