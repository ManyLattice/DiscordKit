//
//  DAVECoordinatorTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitBot

final class DAVECoordinatorTests: XCTestCase {

    //MARK: - Properties

    private var crypto = MockDAVECrypto()

    //MARK: - Tests

    func testStartWithDaveSendsKeyPackageForChannelGroup() {
        var coordinator = makeCoordinator(version: 1)

        XCTAssertEqual(coordinator.start(), [.daveKeyPackage(Data([0x4B, 1]))])
        XCTAssertEqual(crypto.calls, [.reinit(version: 1, groupID: 333, selfUserID: "222")])
    }

    func testStartWithoutDavePassesFramesThrough() {
        var coordinator = makeCoordinator(version: 0)

        XCTAssertEqual(coordinator.start(), [])
        XCTAssertEqual(crypto.calls, [.reset, .setPassthrough(true)])
        XCTAssertEqual(coordinator.encrypt(Data([1, 2]), ssrc: 1), Data([1, 2]))
    }

    func testProposalsAnswerWithCommitAndRecognizeSelf() {
        var coordinator = startedCoordinator()
        crypto.proposalsResult = Data([0xC0, 0xFF])

        let output = coordinator.handle(.daveProposals(Data([0x00, 0x01])), connectedUserIDs: ["444"])

        XCTAssertEqual(output, [.daveCommitWelcome(Data([0xC0, 0xFF]))])
        XCTAssertEqual(crypto.calls.last, .processProposals(Data([0x00, 0x01]), ["444", "222"]))
    }

    func testRejectedProposalsSendNothing() {
        var coordinator = startedCoordinator()

        XCTAssertEqual(coordinator.handle(.daveProposals(Data([0x01])), connectedUserIDs: []), [])
    }

    func testInitialWelcomeSwitchesKeysImmediately() {
        var coordinator = startedCoordinator()

        let output = coordinator.handle(.daveWelcome(transitionID: 0, welcome: Data([0x57])), connectedUserIDs: ["444"])

        XCTAssertEqual(output, [])
        XCTAssertEqual(crypto.calls.suffix(3), [
            .processWelcome(Data([0x57]), ["444", "222"]),
            .useLatestKeyRatchet,
            .setPassthrough(false)
        ])
    }

    func testCommitWaitsForExecuteBeforeSwitchingKeys() {
        var coordinator = startedCoordinator()

        let ready = coordinator.handle(.daveAnnounceCommitTransition(transitionID: 5, commit: Data([0xC0])), connectedUserIDs: [])
        XCTAssertEqual(ready, [.daveTransitionReady(transitionID: 5)])
        XCTAssertFalse(crypto.calls.contains(.useLatestKeyRatchet))

        XCTAssertEqual(coordinator.handle(.daveExecuteTransition(transitionID: 5), connectedUserIDs: []), [])
        XCTAssertEqual(crypto.calls.suffix(2), [.useLatestKeyRatchet, .setPassthrough(false)])
        XCTAssertTrue(coordinator.pendingTransitions.isEmpty)
    }

    func testIgnoredCommitDoesNothing() {
        var coordinator = startedCoordinator()
        crypto.commitOutcome = .ignored

        XCTAssertEqual(coordinator.handle(.daveAnnounceCommitTransition(transitionID: 5, commit: Data()), connectedUserIDs: []), [])
        XCTAssertTrue(coordinator.pendingTransitions.isEmpty)
    }

    func testFailedCommitReportsInvalidAndRejoinsOnce() {
        var coordinator = startedCoordinator()
        crypto.commitOutcome = .failed

        let output = coordinator.handle(.daveAnnounceCommitTransition(transitionID: 7, commit: Data()), connectedUserIDs: [])

        XCTAssertEqual(output, [.daveInvalidCommitWelcome(transitionID: 7), .daveKeyPackage(Data([0x4B, 2]))])
        XCTAssertEqual(coordinator.handle(.daveWelcome(transitionID: 7, welcome: Data()), connectedUserIDs: []), [.daveTransitionReady(transitionID: 7)])
    }

    func testFailedWelcomeWhileRecoveringIsNotReportedTwice() {
        var coordinator = startedCoordinator()
        crypto.welcomeSucceeds = false

        XCTAssertEqual(coordinator.handle(.daveWelcome(transitionID: 3, welcome: Data()), connectedUserIDs: []).count, 2)
        XCTAssertEqual(coordinator.handle(.daveWelcome(transitionID: 4, welcome: Data()), connectedUserIDs: []), [])
    }

    func testDowngradeToPassthroughHappensOnExecute() {
        var coordinator = startedCoordinator()
        _ = coordinator.handle(.daveWelcome(transitionID: 0, welcome: Data()), connectedUserIDs: [])

        XCTAssertEqual(coordinator.handle(.davePrepareTransition(transitionID: 9, protocolVersion: 0), connectedUserIDs: []),
                       [.daveTransitionReady(transitionID: 9)])
        XCTAssertEqual(coordinator.encrypt(Data([1]), ssrc: 1), Data([0xE0, 1]))

        _ = coordinator.handle(.daveExecuteTransition(transitionID: 9), connectedUserIDs: [])

        XCTAssertEqual(coordinator.protocolVersion, 0)
        XCTAssertEqual(crypto.calls.last, .setPassthrough(true))
        XCTAssertEqual(coordinator.encrypt(Data([1]), ssrc: 1), Data([1]))
    }

    func testTransitionZeroExecutesWithoutReady() {
        var coordinator = startedCoordinator()

        XCTAssertEqual(coordinator.handle(.davePrepareTransition(transitionID: 0, protocolVersion: 0), connectedUserIDs: []), [])
        XCTAssertEqual(coordinator.protocolVersion, 0)
    }

    func testExecuteOfUnknownTransitionIsIgnored() {
        var coordinator = startedCoordinator()
        let callsBefore = crypto.calls

        _ = coordinator.handle(.daveExecuteTransition(transitionID: 42), connectedUserIDs: [])

        XCTAssertEqual(crypto.calls, callsBefore)
        XCTAssertEqual(coordinator.protocolVersion, 1)
    }

    func testNewEpochOneRecreatesGroup() {
        var coordinator = makeCoordinator(version: 0)
        _ = coordinator.start()

        let output = coordinator.handle(.davePrepareEpoch(epoch: 1, protocolVersion: 1), connectedUserIDs: [])

        XCTAssertEqual(output, [.daveKeyPackage(Data([0x4B, 1]))])
        XCTAssertEqual(coordinator.protocolVersion, 1)
        XCTAssertEqual(coordinator.handle(.davePrepareEpoch(epoch: 2, protocolVersion: 1), connectedUserIDs: []), [])
    }

    func testExternalSenderIsForwarded() {
        var coordinator = startedCoordinator()

        _ = coordinator.handle(.daveExternalSender(Data([0xEE])), connectedUserIDs: [])

        XCTAssertEqual(crypto.calls.last, .setExternalSender(Data([0xEE])))
    }

    func testSilenceIsNeverEncrypted() {
        let coordinator = startedCoordinator()

        XCTAssertEqual(coordinator.encrypt(RTPPacketizer.silenceFrame, ssrc: 1), RTPPacketizer.silenceFrame)
        XCTAssertEqual(coordinator.encrypt(Data([7]), ssrc: 1), Data([0xE0, 7]))
    }

    //MARK: - Private methods

    private func makeCoordinator(version: Int) -> DAVECoordinator {
        DAVECoordinator(crypto: crypto, protocolVersion: version, channelID: "333", selfUserID: "222")
    }

    private func startedCoordinator() -> DAVECoordinator {
        var coordinator = makeCoordinator(version: 1)
        _ = coordinator.start()
        return coordinator
    }
}
