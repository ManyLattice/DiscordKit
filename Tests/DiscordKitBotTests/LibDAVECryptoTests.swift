//
//  LibDAVECryptoTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitBot

final class LibDAVECryptoTests: XCTestCase {

    //MARK: - Tests

    func testVoiceConnectionUsesLibDaveByDefault() {
        XCTAssertTrue(VoiceConnection.defaultCrypto() is LibDAVECrypto)
    }

    func testSupportsDaveVersionOne() throws {
        let crypto = try XCTUnwrap(LibDAVECrypto())

        XCTAssertGreaterThanOrEqual(crypto.maxProtocolVersion, 1)
    }

    func testProducesFreshKeyPackageAfterReinit() throws {
        let crypto = try XCTUnwrap(LibDAVECrypto())

        crypto.reinit(protocolVersion: 1, groupID: 333, selfUserID: "222")
        let first = crypto.keyPackage()
        crypto.reinit(protocolVersion: 1, groupID: 333, selfUserID: "222")
        let second = crypto.keyPackage()

        XCTAssertGreaterThan(first.count, 100)
        XCTAssertNotEqual(first, second)
    }

    func testEncryptWithoutKeysFailsSoCallerFallsBack() throws {
        let crypto = try XCTUnwrap(LibDAVECrypto())
        crypto.reinit(protocolVersion: 1, groupID: 333, selfUserID: "222")
        crypto.setPassthrough(false)

        XCTAssertNil(crypto.encrypt(Data([0xFC, 0x01, 0x02]), ssrc: 7))
    }

    func testPassthroughKeepsFrame() throws {
        let crypto = try XCTUnwrap(LibDAVECrypto())
        crypto.setPassthrough(true)

        XCTAssertEqual(crypto.encrypt(Data([0xFC, 0x01, 0x02]), ssrc: 7), Data([0xFC, 0x01, 0x02]))
    }

    func testDoesNotAcceptGarbageCommitOrWelcome() throws {
        let crypto = try XCTUnwrap(LibDAVECrypto())
        crypto.reinit(protocolVersion: 1, groupID: 333, selfUserID: "222")

        XCTAssertNotEqual(crypto.processCommit(Data([0x00, 0x01, 0x02])), .accepted)
        XCTAssertFalse(crypto.processWelcome(Data([0x00, 0x01]), recognizedUserIDs: ["222"]))
        XCTAssertNil(crypto.processProposals(Data([0x00, 0x01]), recognizedUserIDs: ["222"]))
    }
}
