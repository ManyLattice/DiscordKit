//
//  VoiceFramePacerTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
@testable import DiscordKitBot

final class VoiceFramePacerTests: XCTestCase {

    //MARK: - Tests

    // Wake-ups on a loaded machine can be tens of milliseconds late, so only early sends and accumulated drift are checked.
    func testSendsFramesOnA20MillisecondGridThenSilence() async throws {
        let frames = (0..<20).map { Data([UInt8($0)]) }
        let clock = ContinuousClock()
        let start = clock.now
        var sent: [(Data, Duration)] = []

        let count = try await VoiceFramePacer().play(frames.async) { frame in
            sent.append((frame, clock.now - start))
        }

        XCTAssertEqual(count, 25)
        XCTAssertEqual(sent.map(\.0), frames + Array(repeating: RTPPacketizer.silenceFrame, count: 5))
        for (index, entry) in sent.enumerated() {
            XCTAssertGreaterThanOrEqual(entry.1, .milliseconds(20 * index) - .milliseconds(1), "frame \(index) sent early")
        }
        let last = try XCTUnwrap(sent.last?.1)
        XCTAssertLessThan(last, .milliseconds(20 * 24 + 150), "delays accumulate instead of catching up")
    }

    func testEmptyInputStillSendsSilence() async throws {
        var sent: [Data] = []

        let count = try await VoiceFramePacer().play([Data]().async) { sent.append($0) }

        XCTAssertEqual(count, 5)
        XCTAssertEqual(sent, Array(repeating: RTPPacketizer.silenceFrame, count: 5))
    }
}

private extension Array {
    var async: AsyncStream<Element> {
        AsyncStream { continuation in
            forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}
