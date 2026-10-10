//
//  AutocompleteInteraction.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 10.10.2026
//

import Foundation
import DiscordKitCore

/// A user typing in an autocomplete option; the handler returns suggestions for ``query``
public class AutocompleteInteraction {

    //MARK: - Properties

    public typealias Handler = (_ interaction: AutocompleteInteraction) async -> [AppCommandOptionChoice]
    public typealias OptionData = Interaction.Data.AppCommandData.OptionData

    public let commandName: String
    /// Name of the option being typed in
    public let focusedOption: String?
    /// What the user typed so far
    public let query: String
    public let guildID: Snowflake?
    public let channelID: Snowflake?
    public let userID: Snowflake?

    private let optionValues: [String: OptionData.Value]

    //MARK: - Init

    init(data: Interaction.Data.AppCommandData, interaction: Interaction) {
        let options = Self.flatten(data.options ?? [])
        let focused = options.first { $0.focused == true }
        self.commandName = data.name
        self.focusedOption = focused?.name
        self.query = focused?.value.map(Self.text) ?? ""
        self.guildID = interaction.guildID
        self.channelID = interaction.channelID
        self.userID = interaction.member?.user?.id ?? interaction.user?.id
        self.optionValues = Dictionary(
            options.compactMap { option in option.value.map { (option.name, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    //MARK: - Public methods

    /// Value already entered in another option, as text
    public func optionValue(of name: String) -> String? {
        optionValues[name].map(Self.text)
    }

    //MARK: - Private methods


    private static func flatten(_ options: [OptionData]) -> [OptionData] {
        options.flatMap { [$0] + flatten($0.options ?? []) }
    }

    private static func text(_ value: OptionData.Value) -> String {
        switch value {
        case .string(let text): return text
        case .integer(let number): return String(number)
        case .double(let number): return String(number)
        case .boolean(let flag): return String(flag)
        }
    }
}
