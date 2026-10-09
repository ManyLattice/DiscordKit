//
//  VoiceJoinRegistryTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
import DiscordKitCore
@testable import DiscordKitBot

final class VoiceJoinRegistryTests: XCTestCase {

    //MARK: - Tests

    func testResumesWithInfoWhenBothEventsArrive() async throws {
        let registry = VoiceJoinRegistry()

        let info = try await withCheckedThrowingContinuation { continuation in
            Task {
                await registry.register(makeHandshake(), id: UUID(), continuation: continuation)
                await registry.receive(VoiceFixtures.server())
                await registry.receive(VoiceFixtures.state())
            }
        }

        XCTAssertEqual(info, VoiceFixtures.expectedInfo)
    }

    func testNewJoinSupersedesPendingOne() async {
        let registry = VoiceJoinRegistry()
        let first = Task {
            try await withCheckedThrowingContinuation { continuation in
                Task { await registry.register(self.makeHandshake(), id: UUID(), continuation: continuation) }
            }
        }
        await waitUntilPending(registry)

        let second = Task {
            try await withCheckedThrowingContinuation { continuation in
                Task { await registry.register(self.makeHandshake(), id: UUID(), continuation: continuation) }
            }
        }

        await assertThrows(first, VoiceJoinError.superseded)
        await registry.cancel(guildID: "111")
        await assertThrows(second, VoiceJoinError.superseded)
    }

    func testStaleTimeoutDoesNotFailNewerJoin() async throws {
        let registry = VoiceJoinRegistry()
        let staleID = UUID()

        let info = try await withCheckedThrowingContinuation { continuation in
            Task {
                await registry.register(makeHandshake(), id: UUID(), continuation: continuation)
                await registry.fail(guildID: "111", id: staleID, error: .timedOut)
                await registry.receive(VoiceFixtures.state())
                await registry.receive(VoiceFixtures.server())
            }
        }

        XCTAssertEqual(info, VoiceFixtures.expectedInfo)
    }

    func testTimeoutFailsMatchingJoin() async {
        let registry = VoiceJoinRegistry()
        let joinID = UUID()
        let join = Task {
            try await withCheckedThrowingContinuation { continuation in
                Task {
                    await registry.register(self.makeHandshake(), id: joinID, continuation: continuation)
                    await registry.fail(guildID: "111", id: joinID, error: .timedOut)
                }
            }
        }

        await assertThrows(join, VoiceJoinError.timedOut)
    }

    //MARK: - Private methods

    private func makeHandshake() -> VoiceHandshake {
        VoiceHandshake(guildID: "111", channelID: "333", userID: "222")
    }

    private func waitUntilPending(_ registry: VoiceJoinRegistry) async {
        while await !registry.hasPending(guildID: "111") {
            await Task.yield()
        }
    }

    private func assertThrows(
        _ task: Task<VoiceConnectionInfo, Error>,
        _ expected: VoiceJoinError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await task.value
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? VoiceJoinError, expected, file: file, line: line)
        }
    }
}
