//
//  VoiceWebSocketTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
import Network
@testable import DiscordKitBot

final class VoiceWebSocketTests: XCTestCase {

    //MARK: - Tests

    func testDeliversTextBinaryAndServerCloseCode() async throws {
        let server = try EchoWebSocketServer()
        let port = try await server.start()
        let url = try XCTUnwrap(URL(string: "ws://127.0.0.1:\(port)"))
        let socket = VoiceWebSocket(url: url)
        var events = socket.events.makeAsyncIterator()

        socket.connect()
        let opened = await events.next()
        XCTAssertEqual(opened, .opened)

        try await socket.send(.text(#"{"op":3}"#))
        let text = await events.next()
        XCTAssertEqual(text, .text(#"{"op":3}"#))

        try await socket.send(.binary(Data([26, 1, 2])))
        let binary = await events.next()
        XCTAssertEqual(binary, .binary(Data([26, 1, 2])))

        try await socket.send(.text("close-4015"))
        let closed = await events.next()
        XCTAssertEqual(closed, .closed(code: 4015))
        let end = await events.next()
        XCTAssertNil(end)

        server.stop()
    }

    func testLocalCloseFinishesStream() async throws {
        let server = try EchoWebSocketServer()
        let port = try await server.start()
        let socket = VoiceWebSocket(url: try XCTUnwrap(URL(string: "ws://127.0.0.1:\(port)")))
        var events = socket.events.makeAsyncIterator()

        socket.connect()
        _ = await events.next()
        socket.close()

        let closed = await events.next()
        XCTAssertEqual(closed, .closed(code: 1000))
        let end = await events.next()
        XCTAssertNil(end)

        server.stop()
    }
}

private final class EchoWebSocketServer {

    //MARK: - Properties

    private let listener: NWListener
    private let queue = DispatchQueue(label: "echo-websocket-server")

    //MARK: - Init

    init() throws {
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
        listener = try NWListener(using: parameters, on: .any)
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

    func stop() {
        listener.cancel()
    }

    //MARK: - Private methods

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self, error == nil, let data,
                  let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
            else { return }

            if metadata.opcode == .text, String(decoding: data, as: UTF8.self) == "close-4015" {
                let close = NWProtocolWebSocket.Metadata(opcode: .close)
                close.closeCode = .privateCode(4015)
                let closeContext = NWConnection.ContentContext(identifier: "close", metadata: [close])
                connection.send(content: nil, contentContext: closeContext, isComplete: true, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            let echo = NWProtocolWebSocket.Metadata(opcode: metadata.opcode)
            let echoContext = NWConnection.ContentContext(identifier: "echo", metadata: [echo])
            connection.send(content: data, contentContext: echoContext, isComplete: true, completion: .idempotent)
            self.receive(on: connection)
        }
    }
}
