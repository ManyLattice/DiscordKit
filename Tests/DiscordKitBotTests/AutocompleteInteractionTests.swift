//
//  AutocompleteInteractionTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import XCTest
@testable import DiscordKitBot
@testable import DiscordKitCore

final class AutocompleteInteractionTests: XCTestCase {

    //MARK: - Tests

    func testFocusedStringOptionGivesQuery() throws {
        let autocomplete = try interaction(options: """
        [{"name": "link", "type": 3, "value": "lofi", "focused": true}]
        """)

        XCTAssertEqual(autocomplete.commandName, "play")
        XCTAssertEqual(autocomplete.focusedOption, "link")
        XCTAssertEqual(autocomplete.query, "lofi")
    }

    func testFocusedIntegerOptionTypedAsTextDecodes() throws {
        let autocomplete = try interaction(options: """
        [{"name": "volume", "type": 4, "value": "4", "focused": true}]
        """)

        XCTAssertEqual(autocomplete.focusedOption, "volume")
        XCTAssertEqual(autocomplete.query, "4")
    }

    func testFocusedOptionInsideSubcommandAndOtherValues() throws {
        let autocomplete = try interaction(options: """
        [{"name": "queue", "type": 1, "options": [
          {"name": "position", "type": 4, "value": 2},
          {"name": "track", "type": 3, "value": "", "focused": true}
        ]}]
        """)

        XCTAssertEqual(autocomplete.focusedOption, "track")
        XCTAssertEqual(autocomplete.query, "")
        XCTAssertEqual(autocomplete.optionValue(of: "position"), "2")
    }

    func testAutocompleteResultEncodesChoices() throws {
        let response = InteractionResponse(
            type: .appCommandAutocompleteResult,
            data: .autocompleteResult([AppCommandOptionChoice(name: "Lofi", value: .string("lofi"))])
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: DiscordREST.encoder.encode(response)) as? [String: Any])
        let choices = try XCTUnwrap((object["data"] as? [String: Any])?["choices"] as? [[String: Any]])

        XCTAssertEqual(object["type"] as? Int, 8)
        XCTAssertEqual(choices.first?["name"] as? String, "Lofi")
        XCTAssertEqual(choices.first?["value"] as? String, "lofi")
    }

    //MARK: - Private methods

    private func interaction(options: String) throws -> AutocompleteInteraction {
        let json = """
        {"id": "900", "application_id": "100", "type": 4, "token": "t", "version": 1, "guild_id": "111",
         "data": {"id": "300", "name": "play", "type": 1, "options": \(options)}}
        """
        let interaction = try DiscordREST.decoder.decode(Interaction.self, from: Data(json.utf8))
        var commandData: Interaction.Data.AppCommandData?
        if case .applicationCommand(let data) = interaction.data {
            commandData = data
        }
        return AutocompleteInteraction(data: try XCTUnwrap(commandData), interaction: interaction)
    }
}
