//
//  VoiceOpcode.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum VoiceOpcode: Int, Codable {
    case identify = 0
    case selectProtocol = 1
    case ready = 2
    case heartbeat = 3
    case sessionDescription = 4
    case speaking = 5
    case heartbeatAck = 6
    case resume = 7
    case hello = 8
    case resumed = 9
    case clientsConnect = 11
    case clientDisconnect = 13
    case davePrepareTransition = 21
    case daveExecuteTransition = 22
    case daveTransitionReady = 23
    case davePrepareEpoch = 24
    case daveMLSExternalSender = 25
    case daveMLSKeyPackage = 26
    case daveMLSProposals = 27
    case daveMLSCommitWelcome = 28
    case daveMLSAnnounceCommitTransition = 29
    case daveMLSWelcome = 30
    case daveMLSInvalidCommitWelcome = 31
}
