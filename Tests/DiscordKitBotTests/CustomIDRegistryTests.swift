//
//  CustomIDRegistryTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class CustomIDRegistryTests: XCTestCase {

    //MARK: - Tests

    func testExactIDWinsOverPrefix() async throws {
        var registry = CustomIDRegistry<ComponentInteraction.Handler>()
        let calls = CallRecorder()
        registry.register(prefix: "vote:") { _ in calls.record("prefix") }
        registry.register("vote:42") { _ in calls.record("exact") }

        await registry.handler(for: "vote:42")?(try clickInteraction())

        XCTAssertEqual(calls.names, ["exact"])
    }

    func testLongestPrefixWins() async throws {
        var registry = CustomIDRegistry<ComponentInteraction.Handler>()
        let calls = CallRecorder()
        registry.register(prefix: "vote:") { _ in calls.record("short") }
        registry.register(prefix: "vote:yes:") { _ in calls.record("long") }

        await registry.handler(for: "vote:yes:42")?(try clickInteraction())
        await registry.handler(for: "vote:no:42")?(try clickInteraction())

        XCTAssertEqual(calls.names, ["long", "short"])
    }

    func testUnknownIDHasNoHandler() {
        var registry = CustomIDRegistry<ComponentInteraction.Handler>()
        registry.register(prefix: "vote:") { _ in }
        registry.register("spin") { _ in }

        XCTAssertNil(registry.handler(for: "spin2"))
        XCTAssertNil(registry.handler(for: "vot"))
    }

    //MARK: - Private methods

    private func clickInteraction() throws -> ComponentInteraction {
        let interaction = try DiscordREST.decoder.decode(Interaction.self, from: Data("""
        {"id": "900", "application_id": "100", "type": 3, "token": "t", "version": 1,
         "data": {"custom_id": "any", "component_type": 2}}
        """.utf8))
        var componentData: Interaction.Data.MessageComponentData?
        if case .messageComponent(let data) = interaction.data {
            componentData = data
        }
        return ComponentInteraction(
            data: try XCTUnwrap(componentData), interaction: interaction, rest: DiscordREST(), applicationID: "100"
        )
    }
}

private final class CallRecorder {
    private(set) var names: [String] = []

    func record(_ name: String) {
        names.append(name)
    }
}
