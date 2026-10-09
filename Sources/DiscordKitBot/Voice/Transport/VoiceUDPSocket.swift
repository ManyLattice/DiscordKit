//
//  VoiceUDPSocket.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import Network

public final class VoiceUDPSocket {

    //MARK: - Properties

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "dk-voice-udp")
    // Touched only on `queue`.
    private var discoveryWaiter: (attempt: Int, continuation: CheckedContinuation<(address: String, port: UInt16)?, Never>)?
    private var discoveryAttempt = 0

    //MARK: - Init

    public init(host: String, port: UInt16) {
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? .any,
            using: .udp
        )
    }

    //MARK: - Public methods

    public func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [connection] state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: VoiceGatewayError.ipDiscoveryFailed)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
        queue.async { self.receiveLoop() }
    }

    public func send(_ packet: Data) {
        connection.send(content: packet, completion: .idempotent)
    }

    public func discoverIP(ssrc: UInt32, attempts: Int = 5, timeout: TimeInterval = 1) async throws -> (address: String, port: UInt16) {
        for _ in 0..<attempts {
            if let response = await requestDiscovery(ssrc: ssrc, timeout: timeout) {
                return response
            }
        }
        throw VoiceGatewayError.ipDiscoveryFailed
    }

    public func close() {
        connection.cancel()
        queue.async { self.finishDiscovery(attempt: self.discoveryAttempt, with: nil) }
    }

    //MARK: - Private methods

    private func requestDiscovery(ssrc: UInt32, timeout: TimeInterval) async -> (address: String, port: UInt16)? {
        await withCheckedContinuation { continuation in
            queue.async {
                self.discoveryAttempt += 1
                let attempt = self.discoveryAttempt
                self.discoveryWaiter = (attempt, continuation)
                self.send(VoiceIPDiscovery.request(ssrc: ssrc))
                self.queue.asyncAfter(deadline: .now() + timeout) {
                    self.finishDiscovery(attempt: attempt, with: nil)
                }
            }
        }
    }

    private func finishDiscovery(attempt: Int, with response: (address: String, port: UInt16)?) {
        guard let waiter = discoveryWaiter, waiter.attempt == attempt else { return }
        discoveryWaiter = nil
        waiter.continuation.resume(returning: response)
    }

    private func receiveLoop() {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data, let response = VoiceIPDiscovery.parseResponse(data) {
                self.finishDiscovery(attempt: self.discoveryAttempt, with: response)
            }
            if error == nil {
                self.receiveLoop()
            }
        }
    }
}
