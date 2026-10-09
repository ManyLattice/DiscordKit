//
//  OpusEncoder.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

#if canImport(AVFoundation)
import Foundation
import AVFoundation

public final class OpusEncoder {

    //MARK: - Properties

    public static let sampleRate = 48_000.0
    public static let channels: AVAudioChannelCount = 2
    public static let samplesPerFrame: AVAudioFrameCount = 960
    public static let bytesPerFrame = Int(samplesPerFrame) * Int(channels) * MemoryLayout<Int16>.size

    private let pcmFormat: AVAudioFormat
    private let converter: AVAudioConverter
    private let opusFormat: AVAudioFormat
    private var pending: AVAudioPCMBuffer?
    private var finished = false

    //MARK: - Init

    public init(bitRate: Int = 96_000) throws {
        var description = AudioStreamBasicDescription(
            mSampleRate: Self.sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: Self.samplesPerFrame,
            mBytesPerFrame: 0,
            mChannelsPerFrame: Self.channels,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Self.sampleRate, channels: Self.channels, interleaved: true),
              let opusFormat = AVAudioFormat(streamDescription: &description),
              let converter = AVAudioConverter(from: pcmFormat, to: opusFormat)
        else { throw AudioSourceError.unsupported }
        converter.bitRate = bitRate
        self.pcmFormat = pcmFormat
        self.opusFormat = opusFormat
        self.converter = converter
    }

    //MARK: - Public methods

    /// Encodes one 20 ms frame of 48 kHz stereo interleaved Int16 PCM. A shorter last frame is padded with silence.
    public func encode(pcm: Data) throws -> [Data] {
        guard pcm.count <= Self.bytesPerFrame,
              let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: Self.samplesPerFrame),
              let channelData = buffer.int16ChannelData
        else { throw AudioSourceError.invalidInput }
        buffer.frameLength = Self.samplesPerFrame
        let destination = UnsafeMutableRawPointer(channelData[0])
        destination.initializeMemory(as: UInt8.self, repeating: 0, count: Self.bytesPerFrame)
        pcm.copyBytes(to: destination.assumingMemoryBound(to: UInt8.self), count: pcm.count)
        pending = buffer
        return try drain()
    }

    public func flush() throws -> [Data] {
        finished = true
        return try drain()
    }

    //MARK: - Private methods

    private func drain() throws -> [Data] {
        var packets: [Data] = []
        while true {
            let output = AVAudioCompressedBuffer(format: opusFormat, packetCapacity: 4, maximumPacketSize: converter.maximumOutputPacketSize)
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { [self] _, inputStatus in
                if let buffer = pending {
                    pending = nil
                    inputStatus.pointee = .haveData
                    return buffer
                }
                inputStatus.pointee = finished ? .endOfStream : .noDataNow
                return nil
            }
            if let error { throw error }
            packets += Self.packets(in: output)
            if status != .haveData || output.packetCount == 0 {
                return packets
            }
        }
    }

    private static func packets(in buffer: AVAudioCompressedBuffer) -> [Data] {
        guard let descriptions = buffer.packetDescriptions else { return [] }
        return (0..<Int(buffer.packetCount)).map { index in
            let description = descriptions[index]
            return Data(bytes: buffer.data.advanced(by: Int(description.mStartOffset)), count: Int(description.mDataByteSize))
        }
    }
}
#endif
