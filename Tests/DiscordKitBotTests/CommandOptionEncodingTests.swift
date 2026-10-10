//
//  CommandOptionEncodingTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class CommandOptionEncodingTests: XCTestCase {

    //MARK: - Tests

    func testEntityOptionsEncodeTheirTypes() throws {
        let options = try encodedOptions {
            UserOption("target", description: "Who").required()
            ChannelOption("room", description: "Where")
            RoleOption("rank", description: "Role")
            MentionableOption("who", description: "Anyone")
            AttachmentOption("file", description: "File")
        }

        XCTAssertEqual(options.map { $0["type"] as? Int }, [6, 7, 8, 9, 11])
        XCTAssertEqual(options.map { $0["name"] as? String }, ["target", "room", "rank", "who", "file"])
        XCTAssertEqual(options[0]["required"] as? Bool, true)
        XCTAssertNil(options[1]["required"])
    }

    func testChannelOptionEncodesChannelTypes() throws {
        let options = try encodedOptions {
            ChannelOption("room", description: "Where", channelTypes: [.voice, .stageVoice])
        }

        XCTAssertEqual(options[0]["channel_types"] as? [Int], [2, 13])
    }

    func testChannelOptionWithoutTypesOmitsChannelTypes() throws {
        let options = try encodedOptions {
            ChannelOption("room", description: "Where")
        }

        XCTAssertNil(options[0]["channel_types"])
    }

    //MARK: - Private methods

    private func encodedOptions(@OptionBuilder _ options: () -> [CommandOption]) throws -> [[String: Any]] {
        let command = NewAppCommand("pick", description: "Pick", options: options) { _ in }
        let object = try JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(command)) as? [String: Any]
        return try XCTUnwrap(object?["options"] as? [[String: Any]])
    }
}
