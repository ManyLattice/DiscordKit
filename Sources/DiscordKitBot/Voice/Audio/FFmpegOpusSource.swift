//
//  FFmpegOpusSource.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

#if canImport(AVFoundation) && os(macOS)
import Foundation

public enum FFmpegOpusSource {

    //MARK: - Public methods

    public static func frames(input: String, inputArguments: [String] = []) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            guard let ffmpeg = ExecutableLocator.find("ffmpeg") else {
                continuation.finish(throwing: AudioSourceError.executableNotFound("ffmpeg"))
                return
            }
            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = ["-hide_banner", "-loglevel", "error", "-nostdin"]
                + inputArguments
                + ["-i", input, "-f", "s16le", "-ar", "48000", "-ac", "2", "pipe:1"]
            let output = Pipe()
            let errors = Pipe()
            process.standardOutput = output
            process.standardError = errors

            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }

            Thread.detachNewThread {
                do {
                    let encoder = try OpusEncoder()
                    try process.run()
                    let reader = output.fileHandleForReading
                    var pcm = Data()
                    while true {
                        let chunk = reader.readData(ofLength: OpusEncoder.bytesPerFrame - pcm.count)
                        if chunk.isEmpty { break }
                        pcm.append(chunk)
                        if pcm.count == OpusEncoder.bytesPerFrame {
                            try encoder.encode(pcm: pcm).forEach { continuation.yield($0) }
                            pcm.removeAll(keepingCapacity: true)
                        }
                    }
                    if !pcm.isEmpty {
                        try encoder.encode(pcm: pcm).forEach { continuation.yield($0) }
                    }
                    try encoder.flush().forEach { continuation.yield($0) }
                    process.waitUntilExit()

                    if process.terminationReason == .exit, process.terminationStatus != 0 {
                        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                        throw AudioSourceError.processFailed(
                            tool: "ffmpeg",
                            status: process.terminationStatus,
                            message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
#endif
