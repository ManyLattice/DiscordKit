//
//  ModalTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class ModalTests: XCTestCase {

    //MARK: - Tests

    func testModalResponseWrapsEachInputInRow() throws {
        let modal = Modal(id: "story", title: "Твоя история", inputs: [
            TextInput(id: "name", label: "Имя", maxLength: 32, required: true),
            TextInput(id: "bio", label: "Биография", style: .paragraph, placeholder: "Кем был до бункера")
        ])
        let response = InteractionResponse(type: .modal, data: .modal(modal))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(response)) as? [String: Any])
        let data = try XCTUnwrap(object["data"] as? [String: Any])
        let rows = try XCTUnwrap(data["components"] as? [[String: Any]])
        let inputs = rows.compactMap { ($0["components"] as? [[String: Any]])?.first }

        XCTAssertEqual(object["type"] as? Int, 9)
        XCTAssertEqual(data["custom_id"] as? String, "story")
        XCTAssertEqual(data["title"] as? String, "Твоя история")
        XCTAssertEqual(rows.map { $0["type"] as? Int }, [1, 1])
        XCTAssertEqual(inputs.map { $0["type"] as? Int }, [4, 4])
        XCTAssertEqual(inputs.map { $0["style"] as? Int }, [1, 2])
        XCTAssertEqual(inputs[0]["max_length"] as? Int, 32)
        XCTAssertEqual(inputs[1]["placeholder"] as? String, "Кем был до бункера")
    }

    func testModalSubmitDecodesRowsAndLabels() throws {
        let modal = try submitted(components: """
        [
          {"type": 1, "components": [{"type": 4, "custom_id": "name", "value": "Михаил"}]},
          {"type": 18, "id": 2, "component": {"type": 4, "custom_id": "bio", "value": "Инженер"}}
        ]
        """)

        XCTAssertEqual(modal.customID, "story")
        XCTAssertEqual(modal.value(of: "name"), "Михаил")
        XCTAssertEqual(modal.value(of: "bio"), "Инженер")
        XCTAssertNil(modal.value(of: "missing"))
        XCTAssertEqual(modal.userID, "444")
    }

    //MARK: - Private methods

    private func submitted(components: String) throws -> ModalInteraction {
        let json = """
        {"id": "900", "application_id": "100", "type": 5, "token": "t", "version": 1, "guild_id": "111",
         "user": {"id": "444", "username": "player", "discriminator": "0", "avatar": null},
         "data": {"custom_id": "story", "components": \(components)}}
        """
        let interaction = try DiscordREST.decoder.decode(Interaction.self, from: Data(json.utf8))
        var modalData: ModalSubmitData?
        if case .modalSubmit(let data) = interaction.data {
            modalData = data
        }
        return ModalInteraction(data: try XCTUnwrap(modalData), interaction: interaction, rest: DiscordREST(), applicationID: "100")
    }
}
