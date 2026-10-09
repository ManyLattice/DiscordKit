//
//  FFmpegOpusSourceTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
import AVFoundation
@testable import DiscordKitBot

final class FFmpegOpusSourceTests: XCTestCase {

    //MARK: - Tests

    func testOneSecondOfAudioBecomesFiftyDecodableFrames() async throws {
        try XCTSkipIf(ExecutableLocator.find("ffmpeg") == nil, "ffmpeg is not installed")

        var frames: [Data] = []
        for try await frame in FFmpegOpusSource.frames(input: "sine=frequency=440:duration=1", inputArguments: ["-f", "lavfi"]) {
            frames.append(frame)
        }

        XCTAssertTrue((50...52).contains(frames.count), "got \(frames.count) frames")
        XCTAssertTrue(frames.allSatisfy { !$0.isEmpty && $0.count <= 1276 })
        let peak = try decodedPeak(frames)
        XCTAssertGreaterThan(peak, 1000, "decoded audio is silent")
    }

    func testMissingInputFailsWithFFmpegMessage() async throws {
        try XCTSkipIf(ExecutableLocator.find("ffmpeg") == nil, "ffmpeg is not installed")

        do {
            for try await _ in FFmpegOpusSource.frames(input: "/nonexistent/track.mp3") {}
            XCTFail("Expected an error")
        } catch let AudioSourceError.processFailed(tool, status, message) {
            XCTAssertEqual(tool, "ffmpeg")
            XCTAssertNotEqual(status, 0)
            XCTAssertTrue(message.contains("No such file"), message)
        }
    }

    func testEncoderPadsShortLastFrame() throws {
        let encoder = try OpusEncoder()

        let packets = try encoder.encode(pcm: Data(count: 100)) + encoder.flush()

        XCTAssertFalse(packets.isEmpty)
    }

    func testEncoderRejectsOversizedFrame() throws {
        let encoder = try OpusEncoder()

        XCTAssertThrowsError(try encoder.encode(pcm: Data(count: OpusEncoder.bytesPerFrame + 2)))
    }

    func testLocatorUsesFallbackDirectoriesWithoutPath() {
        XCTAssertEqual(ExecutableLocator.find("env", environment: [:])?.path, "/usr/bin/env")
        XCTAssertNil(ExecutableLocator.find("not-a-tool-\(UUID().uuidString)", environment: [:]))
    }

    func testLocatorPrefersPathEntries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tool = directory.appendingPathComponent("env")
        FileManager.default.createFile(atPath: tool.path, contents: Data("#!/bin/sh\n".utf8), attributes: [.posixPermissions: 0o755])

        XCTAssertEqual(ExecutableLocator.find("env", environment: ["PATH": directory.path])?.path, tool.path)
    }

    //MARK: - Private methods

    private func decodedPeak(_ frames: [Data]) throws -> Int16 {
        var description = AudioStreamBasicDescription(
            mSampleRate: 48_000, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0,
            mFramesPerPacket: 960, mBytesPerFrame: 0, mChannelsPerFrame: 2, mBitsPerChannel: 0, mReserved: 0
        )
        let opus = try XCTUnwrap(AVAudioFormat(streamDescription: &description))
        let pcm = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000, channels: 2, interleaved: true))
        let converter = try XCTUnwrap(AVAudioConverter(from: opus, to: pcm))
        var peak: Int16 = 0
        var index = 0

        while index < frames.count {
            let output = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: 960))
            var error: NSError?
            _ = converter.convert(to: output, error: &error) { _, status in
                guard index < frames.count else {
                    status.pointee = .endOfStream
                    return nil
                }
                let frame = frames[index]
                index += 1
                let input = AVAudioCompressedBuffer(format: opus, packetCapacity: 1, maximumPacketSize: frame.count)
                frame.copyBytes(to: input.data.assumingMemoryBound(to: UInt8.self), count: frame.count)
                input.packetDescriptions?[0] = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(frame.count))
                input.packetCount = 1
                input.byteLength = UInt32(frame.count)
                status.pointee = .haveData
                return input
            }
            if let error { throw error }
            let samples = try XCTUnwrap(output.int16ChannelData)[0]
            for sample in 0..<Int(output.frameLength) * 2 {
                peak = max(peak, Int16(clamping: samples[sample].magnitude))
            }
        }
        return peak
    }
}
