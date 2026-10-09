//
//  DAVECrypto.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum DAVECommitOutcome: Equatable {
    case accepted
    case ignored
    case failed
}

public protocol DAVECrypto: AnyObject {
    var maxProtocolVersion: Int { get }
    func reinit(protocolVersion: Int, groupID: UInt64, selfUserID: String)
    func reset()
    func setExternalSender(_ externalSender: Data)
    func keyPackage() -> Data
    func processProposals(_ payload: Data, recognizedUserIDs: Set<String>) -> Data?
    func processCommit(_ commit: Data) -> DAVECommitOutcome
    func processWelcome(_ welcome: Data, recognizedUserIDs: Set<String>) -> Bool
    func useLatestKeyRatchet()
    func setPassthrough(_ enabled: Bool)
    func encrypt(_ frame: Data, ssrc: UInt32) -> Data?
}
