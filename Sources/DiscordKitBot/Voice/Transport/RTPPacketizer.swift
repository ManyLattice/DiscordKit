//
//  RTPPacketizer.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import CryptoKit

public struct RTPPacketizer {

    //MARK: - Properties

    public static let samplesPerFrame: UInt32 = 960
    public static let silenceFrame = Data([0xF8, 0xFF, 0xFE])

    public let ssrc: UInt32
    public private(set) var sequence: UInt16
    public private(set) var timestamp: UInt32
    public private(set) var nonce: UInt32
    private let key: SymmetricKey

    //MARK: - Init

    public init(
        ssrc: UInt32,
        secretKey: [UInt8],
        sequence: UInt16 = .random(in: .min ... .max),
        timestamp: UInt32 = .random(in: .min ... .max),
        nonce: UInt32 = 0
    ) {
        self.ssrc = ssrc
        self.key = SymmetricKey(data: secretKey)
        self.sequence = sequence
        self.timestamp = timestamp
        self.nonce = nonce
    }

    //MARK: - Public methods

    public mutating func packet(for payload: Data) throws -> Data {
        var header = Data([0x80, 0x78])
        header.append(bigEndian: sequence)
        header.append(bigEndian: timestamp)
        header.append(bigEndian: ssrc)

        var nonceBytes = Data()
        nonceBytes.append(bigEndian: nonce)
        let fullNonce = try AES.GCM.Nonce(data: nonceBytes + Data(count: 8))
        let sealed = try AES.GCM.seal(payload, using: key, nonce: fullNonce, authenticating: header)

        sequence &+= 1
        timestamp &+= Self.samplesPerFrame
        nonce &+= 1
        return header + sealed.ciphertext + sealed.tag + nonceBytes
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(bigEndian value: T) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
