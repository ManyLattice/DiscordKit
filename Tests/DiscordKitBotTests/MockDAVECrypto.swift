//
//  MockDAVECrypto.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
@testable import DiscordKitBot

final class MockDAVECrypto: DAVECrypto {

    //MARK: - Properties

    enum Call: Equatable {
        case reinit(version: Int, groupID: UInt64, selfUserID: String)
        case reset
        case setExternalSender(Data)
        case processProposals(Data, Set<String>)
        case processCommit(Data)
        case processWelcome(Data, Set<String>)
        case useLatestKeyRatchet
        case setPassthrough(Bool)
    }

    var calls: [Call] = []
    var keyPackageCount = 0
    var proposalsResult: Data?
    var commitOutcome = DAVECommitOutcome.accepted
    var welcomeSucceeds = true
    let maxProtocolVersion = 1

    //MARK: - Public methods

    func reinit(protocolVersion: Int, groupID: UInt64, selfUserID: String) {
        calls.append(.reinit(version: protocolVersion, groupID: groupID, selfUserID: selfUserID))
    }

    func reset() { calls.append(.reset) }

    func setExternalSender(_ externalSender: Data) { calls.append(.setExternalSender(externalSender)) }

    func keyPackage() -> Data {
        keyPackageCount += 1
        return Data([0x4B, UInt8(keyPackageCount)])
    }

    func processProposals(_ payload: Data, recognizedUserIDs: Set<String>) -> Data? {
        calls.append(.processProposals(payload, recognizedUserIDs))
        return proposalsResult
    }

    func processCommit(_ commit: Data) -> DAVECommitOutcome {
        calls.append(.processCommit(commit))
        return commitOutcome
    }

    func processWelcome(_ welcome: Data, recognizedUserIDs: Set<String>) -> Bool {
        calls.append(.processWelcome(welcome, recognizedUserIDs))
        return welcomeSucceeds
    }

    func useLatestKeyRatchet() { calls.append(.useLatestKeyRatchet) }

    func setPassthrough(_ enabled: Bool) { calls.append(.setPassthrough(enabled)) }

    func encrypt(_ frame: Data, ssrc: UInt32) -> Data? { Data([0xE0]) + frame }
}
