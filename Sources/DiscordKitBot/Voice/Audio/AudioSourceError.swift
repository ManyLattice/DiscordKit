//
//  AudioSourceError.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public enum AudioSourceError: Error, Equatable {
    case unsupported
    case invalidInput
    case executableNotFound(String)
    case processFailed(tool: String, status: Int32, message: String)
}
