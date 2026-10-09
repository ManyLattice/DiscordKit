//
//  VoiceGatewayAction.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum VoiceGatewayAction: Equatable {
    case send(VoiceGatewayOutgoing)
    case startHeartbeat(interval: TimeInterval)
    case discoverIP(VoiceGatewayIncoming.VoiceReady)
    case established(VoiceGatewayIncoming.VoiceSessionDescription)
    case resumed
    case reconnectToResume
    case dave(VoiceGatewayIncoming)
    case fail(VoiceGatewayError)
}
