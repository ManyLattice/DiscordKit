//
//  VoiceIPDiscovery.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum VoiceIPDiscovery {

    //MARK: - Public methods

    public static func request(ssrc: UInt32) -> Data {
        var packet = Data([0x00, 0x01, 0x00, 70])
        packet.append(contentsOf: withUnsafeBytes(of: ssrc.bigEndian) { Array($0) })
        packet.append(Data(count: 66))
        return packet
    }

    public static func parseResponse(_ packet: Data) -> (address: String, port: UInt16)? {
        let bytes = [UInt8](packet)
        guard bytes.count == 74, bytes[0] == 0x00, bytes[1] == 0x02 else { return nil }
        let addressBytes = bytes[8..<72].prefix { $0 != 0 }
        guard !addressBytes.isEmpty, let address = String(bytes: addressBytes, encoding: .utf8) else { return nil }
        let port = UInt16(bytes[72]) << 8 | UInt16(bytes[73])
        return (address, port)
    }
}
