//
//  VoiceUDPSocketTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
import Network
@testable import DiscordKitBot

final class VoiceUDPSocketTests: XCTestCase {

    //MARK: - Tests

    func testDiscoversIPAndDeliversPackets() async throws {
        let server = try FakeVoiceUDPServer()
        let port = try await server.start()
        let socket = VoiceUDPSocket(host: "127.0.0.1", port: port)
        try await socket.start()

        let discovered = try await socket.discoverIP(ssrc: 42)
        XCTAssertEqual(discovered.address, "198.51.100.4")
        XCTAssertEqual(discovered.port, 61000)

        socket.send(Data([0x80, 0x78, 0x01]))
        let received = try await server.nextPacket()
        XCTAssertEqual(received, Data([0x80, 0x78, 0x01]))

        socket.close()
        server.stop()
    }

    func testDiscoveryFailsWhenServerIsSilent() async throws {
        let server = try FakeVoiceUDPServer(answersDiscovery: false)
        let port = try await server.start()
        let socket = VoiceUDPSocket(host: "127.0.0.1", port: port)
        try await socket.start()

        do {
            _ = try await socket.discoverIP(ssrc: 42, attempts: 2, timeout: 0.1)
            XCTFail("Expected discovery to fail")
        } catch {
            XCTAssertEqual(error as? VoiceGatewayError, .ipDiscoveryFailed)
        }

        socket.close()
        server.stop()
    }
}

private final class FakeVoiceUDPServer {

    //MARK: - Properties

    private let listener: NWListener
    private let answersDiscovery: Bool
    private let queue = DispatchQueue(label: "fake-voice-udp")
    private let packets: AsyncStream<Data>
    private let packetContinuation: AsyncStream<Data>.Continuation
    private var packetIterator: AsyncStream<Data>.Iterator

    //MARK: - Init

    init(answersDiscovery: Bool = true) throws {
        listener = try NWListener(using: .udp, on: .any)
        self.answersDiscovery = answersDiscovery
        (packets, packetContinuation) = AsyncStream.makeStream(of: Data.self)
        packetIterator = packets.makeAsyncIterator()
    }

    //MARK: - Public methods

    func start() async throws -> UInt16 {
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receive(on: connection)
        }
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: listener.port?.rawValue ?? 0)
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    func nextPacket() async throws -> Data? {
        await packetIterator.next()
    }

    func stop() {
        listener.cancel()
        packetContinuation.finish()
    }

    //MARK: - Private methods

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self, error == nil, let data else { return }
            if data.count == 74, data.first == 0x00, data[data.startIndex + 1] == 0x01 {
                if self.answersDiscovery {
                    connection.send(content: VoiceIPDiscoveryTests.response(address: "198.51.100.4", port: 61000), completion: .idempotent)
                }
            } else {
                self.packetContinuation.yield(data)
            }
            self.receive(on: connection)
        }
    }
}
