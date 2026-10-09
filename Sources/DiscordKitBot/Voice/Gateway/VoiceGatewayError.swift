//
//  VoiceGatewayError.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum VoiceGatewayError: Error, Equatable {
    case malformedBinaryFrame
    case unsupportedEncryptionModes([String])
    case closed(code: Int)
    case ipDiscoveryFailed
}
