//
//  VoiceConnectionTests.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import XCTest
import CryptoKit
import Network
@testable import DiscordKitBot

final class VoiceConnectionTests: XCTestCase {

    //MARK: - Tests

    func testConnectsAndSendsDecryptableAudio() async throws {
        let server = try FakeVoiceServer()
        let wsPort = try await server.start()
        let connection = VoiceConnection(
            info: VoiceFixtures.expectedInfo,
            crypto: nil,
            gatewayURL: try XCTUnwrap(URL(string: "ws://127.0.0.1:\(wsPort)"))
        )

        try await connection.connect()
        let status = await connection.status
        XCTAssertEqual(status, .ready)

        let frames = [Data([0xFC, 0x01]), Data([0xFC, 0x02]), Data([0xFC, 0x03])]
        let sent = try await connection.play(opusFrames: AsyncStream { continuation in
            frames.forEach { continuation.yield($0) }
            continuation.finish()
        })
        XCTAssertEqual(sent, 8)

        var payloads: [Data] = []
        for _ in 0..<8 {
            let packet = try await server.nextRTPPacket()
            payloads.append(try FakeVoiceServer.decrypt(packet))
        }
        XCTAssertEqual(payloads, frames + Array(repeating: RTPPacketizer.silenceFrame, count: 5))

        let identify = try XCTUnwrap(server.receivedOpcodes.first)
        XCTAssertEqual(identify, 0)
        XCTAssertTrue(server.receivedOpcodes.contains(1))
        XCTAssertTrue(server.receivedOpcodes.contains(5))

        await connection.disconnect()
        server.stop()
    }

    func testConnectFailsWhenServerRejectsSession() async throws {
        let server = try FakeVoiceServer(closeCodeOnIdentify: 4006)
        let wsPort = try await server.start()
        let connection = VoiceConnection(
            info: VoiceFixtures.expectedInfo,
            crypto: nil,
            gatewayURL: try XCTUnwrap(URL(string: "ws://127.0.0.1:\(wsPort)"))
        )

        do {
            try await connection.connect()
            XCTFail("Expected connect to fail")
        } catch {
            XCTAssertEqual(error as? VoiceGatewayError, .closed(code: 4006))
        }

        server.stop()
    }
}

private final class FakeVoiceServer {

    //MARK: - Properties

    static let secretKey = Array(UInt8(0)..<32)

    private let wsListener: NWListener
    private let udpListener: NWListener
    private let closeCodeOnIdentify: UInt16?
    private let queue = DispatchQueue(label: "fake-voice-server")
    private let (rtpPackets, rtpContinuation) = AsyncStream.makeStream(of: Data.self)
    private lazy var rtpIterator = rtpPackets.makeAsyncIterator()
    private let lock = NSLock()
    private var opcodes: [Int] = []

    var receivedOpcodes: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return opcodes
    }

    //MARK: - Init

    init(closeCodeOnIdentify: UInt16? = nil) throws {
        let wsParameters = NWParameters.tcp
        wsParameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
        wsListener = try NWListener(using: wsParameters, on: .any)
        udpListener = try NWListener(using: .udp, on: .any)
        self.closeCodeOnIdentify = closeCodeOnIdentify
    }

    //MARK: - Public methods

    func start() async throws -> UInt16 {
        udpListener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receiveUDP(on: connection)
        }
        wsListener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receiveWS(on: connection)
        }
        _ = try await Self.ready(udpListener, queue: queue)
        return try await Self.ready(wsListener, queue: queue)
    }

    func nextRTPPacket() async throws -> Data {
        guard let packet = await rtpIterator.next() else { throw VoiceGatewayError.closed(code: 0) }
        return packet
    }

    func stop() {
        wsListener.cancel()
        udpListener.cancel()
        rtpContinuation.finish()
    }

    static func decrypt(_ packet: Data) throws -> Data {
        let bytes = [UInt8](packet)
        let header = Data(bytes[0..<12])
        let nonce = Data(bytes[(bytes.count - 4)...]) + Data(count: 8)
        let body = bytes[12..<(bytes.count - 4)]
        let box = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: Data(body.dropLast(16)),
            tag: Data(body.suffix(16))
        )
        return try AES.GCM.open(box, using: SymmetricKey(data: secretKey), authenticating: header)
    }

    //MARK: - Private methods

    private static func ready(_ listener: NWListener, queue: DispatchQueue) async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
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

    private func receiveWS(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self, error == nil, let data,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let opcode = object["op"] as? Int
            else { return }
            self.lock.lock()
            self.opcodes.append(opcode)
            self.lock.unlock()

            switch opcode {
            case 0:
                if let closeCode = self.closeCodeOnIdentify {
                    let close = NWProtocolWebSocket.Metadata(opcode: .close)
                    close.closeCode = .privateCode(closeCode)
                    let context = NWConnection.ContentContext(identifier: "close", metadata: [close])
                    connection.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    return
                }
                self.sendText(#"{"op":8,"d":{"v":8,"heartbeat_interval":41250}}"#, on: connection)
                let udpPort = self.udpListener.port?.rawValue ?? 0
                self.sendText("""
                {"op":2,"seq":1,"d":{"ssrc":7,"ip":"127.0.0.1","port":\(udpPort),"modes":["aead_aes256_gcm_rtpsize"]}}
                """, on: connection)
            case 1:
                let key = Self.secretKey.map(String.init).joined(separator: ",")
                self.sendText("""
                {"op":4,"seq":2,"d":{"mode":"aead_aes256_gcm_rtpsize","secret_key":[\(key)],"dave_protocol_version":0}}
                """, on: connection)
            default:
                break
            }
            self.receiveWS(on: connection)
        }
    }

    private func sendText(_ text: String, on connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: Data(text.utf8), contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func receiveUDP(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self, error == nil, let data else { return }
            if data.count == 74, data.first == 0x00, data[data.startIndex + 1] == 0x01 {
                connection.send(content: VoiceIPDiscoveryTests.response(address: "198.51.100.4", port: 61000), completion: .idempotent)
            } else {
                self.rtpContinuation.yield(data)
            }
            self.receiveUDP(on: connection)
        }
    }
}
