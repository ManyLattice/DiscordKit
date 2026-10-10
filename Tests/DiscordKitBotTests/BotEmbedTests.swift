//
//  BotEmbedTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class BotEmbedTests: XCTestCase {

    //MARK: - Tests

    func testEmbedEncodesAuthorImagesAndFooterIcon() throws {
        let embed = BotEmbed()
            .title("Бункер")
            .author("BunkerBot", url: URL(string: "https://bunker.example"), iconURL: URL(string: "https://cdn.example/bot.png"))
            .image(URL(string: "https://cdn.example/map.png"))
            .thumbnail(URL(string: "https://cdn.example/icon.png"))
            .footer("Раунд 1", iconURL: URL(string: "https://cdn.example/clock.png"))
        let object = try encode(embed)

        XCTAssertEqual(object["title"] as? String, "Бункер")
        let author = try XCTUnwrap(object["author"] as? [String: Any])
        XCTAssertEqual(author["name"] as? String, "BunkerBot")
        XCTAssertEqual(author["url"] as? String, "https://bunker.example")
        XCTAssertEqual(author["icon_url"] as? String, "https://cdn.example/bot.png")
        XCTAssertEqual((object["image"] as? [String: Any])?["url"] as? String, "https://cdn.example/map.png")
        XCTAssertEqual((object["thumbnail"] as? [String: Any])?["url"] as? String, "https://cdn.example/icon.png")
        let footer = try XCTUnwrap(object["footer"] as? [String: Any])
        XCTAssertEqual(footer["text"] as? String, "Раунд 1")
        XCTAssertEqual(footer["icon_url"] as? String, "https://cdn.example/clock.png")
    }

    func testEmbedWithoutMediaOmitsThem() throws {
        let object = try encode(BotEmbed().title("Пусто").footer("Без иконки"))

        XCTAssertNil(object["author"])
        XCTAssertNil(object["image"])
        XCTAssertNil(object["thumbnail"])
        XCTAssertNil((object["footer"] as? [String: Any])?["icon_url"])
    }

    func testFieldBuilderSupportsLoopsAndConditions() throws {
        let players = ["Аня", "Борис"]
        let showDead = false
        let embed = BotEmbed {
            BotEmbed.Field("Раунд", value: "1")
            for player in players {
                BotEmbed.Field(player, value: "жив", inline: true)
            }
            if showDead {
                BotEmbed.Field("Выбыли", value: "никто")
            }
        }
        let fields = try XCTUnwrap(encode(embed)["fields"] as? [[String: Any]])

        XCTAssertEqual(fields.map { $0["name"] as? String }, ["Раунд", "Аня", "Борис"])
        XCTAssertEqual(fields[1]["inline"] as? Bool, true)
    }

    //MARK: - Private methods

    private func encode(_ embed: BotEmbed) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(embed)) as? [String: Any])
    }
}
