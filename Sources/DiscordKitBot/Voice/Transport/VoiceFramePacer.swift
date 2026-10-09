//
//  VoiceFramePacer.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public struct VoiceFramePacer {

    //MARK: - Properties

    public static let frameDuration: Duration = .milliseconds(20)
    public static let trailingSilenceFrames = 5

    private let clock = ContinuousClock()

    //MARK: - Init

    public init() {}

    //MARK: - Public methods

    @discardableResult
    public func play<Frames: AsyncSequence>(
        _ frames: Frames,
        isolation: isolated (any Actor)? = #isolation,
        send: (Data) async throws -> Void
    ) async throws -> Int where Frames.Element == Data {
        let start = clock.now
        var index = 0

        for try await frame in frames {
            try await waitForSlot(index, from: start)
            try await send(frame)
            index += 1
        }
        for _ in 0..<Self.trailingSilenceFrames {
            try await waitForSlot(index, from: start)
            try await send(RTPPacketizer.silenceFrame)
            index += 1
        }
        return index
    }

    //MARK: - Private methods

    // Deadlines are measured from the start, not the previous send, so late wake-ups do not accumulate drift.
    private func waitForSlot(_ index: Int, from start: ContinuousClock.Instant) async throws {
        let deadline = start.advanced(by: Self.frameDuration * index)
        if deadline > clock.now {
            try await clock.sleep(until: deadline, tolerance: .milliseconds(1))
        }
    }
}
