//
//  VoiceJoinError.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum VoiceJoinError: Error, Equatable {
    case notConnected
    case timedOut
    case superseded
}
