//
//  VoiceConnection.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import Logging
import DiscordKitCore

public actor VoiceConnection {

    //MARK: - Properties

    public enum Status: Equatable {
        case idle
        case connecting
        case ready
        case closed
    }

    public private(set) var status = Status.idle

    private static let log = Logger(label: "VoiceConnection", level: nil)

    private let info: VoiceConnectionInfo
    private let crypto: DAVECrypto?
    private let gatewayURL: URL?
    private var session: VoiceGatewaySession
    private var socket: VoiceWebSocket?
    private var udp: VoiceUDPSocket?
    private var packetizer: RTPPacketizer?
    private var dave: DAVECoordinator?
    private var eventsTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var readiness: CheckedContinuation<Void, Error>?
    private var closeError: Error?

    //MARK: - Init

    public init(info: VoiceConnectionInfo, crypto: DAVECrypto? = VoiceConnection.defaultCrypto()) {
        self.init(info: info, crypto: crypto, gatewayURL: nil)
    }

    init(info: VoiceConnectionInfo, crypto: DAVECrypto?, gatewayURL: URL?) {
        self.info = info
        self.crypto = crypto
        self.gatewayURL = gatewayURL
        session = VoiceGatewaySession(
            credentials: VoiceCredentials(info),
            maxDaveProtocolVersion: crypto?.maxProtocolVersion ?? 0
        )
    }

    //MARK: - Public methods

    public static func defaultCrypto() -> DAVECrypto? {
        LibDAVECrypto()
    }

    public func connect() async throws {
        guard status == .idle else { return }
        status = .connecting
        try await withCheckedThrowingContinuation { continuation in
            readiness = continuation
            openSocket()
        }
    }

    @discardableResult
    public func play<Frames: AsyncSequence>(opusFrames: Frames) async throws -> Int where Frames.Element == Data {
        guard status == .ready, let ssrc = session.ready?.ssrc else { throw VoiceGatewayError.closed(code: 0) }
        try await send(.speaking(true, ssrc: ssrc))
        defer { Task { try? await self.send(.speaking(false, ssrc: ssrc)) } }

        return try await VoiceFramePacer().play(opusFrames) { frame in
            try self.sendAudio(frame, ssrc: ssrc)
        }
    }

    public func disconnect() {
        session.close()
        finish(with: VoiceGatewayError.closed(code: 1000))
    }

    //MARK: - Private methods

    private func openSocket() {
        guard let url = gatewayURL ?? session.credentials.url else {
            finish(with: VoiceGatewayError.closed(code: 0))
            return
        }
        let socket = VoiceWebSocket(url: url)
        self.socket = socket
        eventsTask = Task { [weak self] in
            for await event in socket.events {
                await self?.handle(event)
            }
        }
        socket.connect()
    }

    private func handle(_ event: VoiceWebSocket.Event) async {
        let actions: [VoiceGatewayAction]
        switch event {
        case .opened:
            actions = session.socketOpened()
        case .text(let text):
            guard let decoded = try? VoiceGatewayIncoming.decode(text: text) else { return }
            actions = session.receive(decoded.message, sequence: decoded.sequence)
        case .binary(let data):
            guard let decoded = try? VoiceGatewayIncoming.decode(binary: data) else { return }
            actions = session.receive(decoded.message, sequence: decoded.sequence)
        case .closed(let code):
            Self.log.info("Voice gateway closed", metadata: ["code": "\(code)", "state": "\(session.state)"])
            actions = session.socketClosed(code: code)
        }
        for action in actions {
            await perform(action)
        }
    }

    private func perform(_ action: VoiceGatewayAction) async {
        switch action {
        case .send(let message):
            try? await send(message)
        case .startHeartbeat(let interval):
            startHeartbeat(interval: interval)
        case .discoverIP(let ready):
            Self.log.info("Voice ready", metadata: ["ssrc": "\(ready.ssrc)", "server": "\(ready.ip):\(ready.port)", "modes": "\(ready.modes)"])
            await discoverIP(ready)
        case .established(let description):
            await establish(description)
        case .resumed:
            break
        case .reconnectToResume:
            Self.log.info("Resuming voice session")
            socket = nil
            openSocket()
        case .dave(let message):
            guard var dave else { return }
            Self.log.info("DAVE message", metadata: ["message": "\(Self.describe(message))"])
            let replies = dave.handle(message, connectedUserIDs: session.connectedUserIDs)
            self.dave = dave
            for reply in replies {
                Self.log.info("DAVE reply", metadata: ["message": "\(Self.describe(reply))"])
                try? await send(reply)
            }
        case .fail(let error):
            Self.log.error("Voice connection failed", metadata: ["error": "\(error)"])
            finish(with: error)
        }
    }

    private func discoverIP(_ ready: VoiceGatewayIncoming.VoiceReady) async {
        let udp = VoiceUDPSocket(host: ready.ip, port: ready.port)
        self.udp = udp
        do {
            try await udp.start()
            let local = try await udp.discoverIP(ssrc: ready.ssrc)
            Self.log.info("IP discovered", metadata: ["address": "\(local.address):\(local.port)"])
            for action in session.ipDiscovered(address: local.address, port: local.port) {
                await perform(action)
            }
        } catch {
            for action in session.ipDiscoveryFailed() {
                await perform(action)
            }
        }
    }

    private func establish(_ description: VoiceGatewayIncoming.VoiceSessionDescription) async {
        guard let ready = session.ready else { return }
        packetizer = RTPPacketizer(ssrc: ready.ssrc, secretKey: description.secretKey)
        Self.log.info("Voice session established", metadata: [
            "mode": "\(description.mode)",
            "dave.version": "\(description.daveProtocolVersion)",
            "dave.available": "\(crypto != nil)"
        ])
        if let crypto {
            var dave = DAVECoordinator(
                crypto: crypto,
                protocolVersion: description.daveProtocolVersion,
                channelID: info.channelID,
                selfUserID: info.userID
            )
            let messages = dave.start()
            self.dave = dave
            for message in messages {
                try? await send(message)
            }
        }
        status = .ready
        readiness?.resume()
        readiness = nil
    }

    private func sendAudio(_ frame: Data, ssrc: UInt32) throws {
        guard status == .ready, var packetizer, let udp else { throw closeError ?? VoiceGatewayError.closed(code: 0) }
        let payload = dave?.encrypt(frame, ssrc: ssrc) ?? frame
        let packet = try packetizer.packet(for: payload)
        self.packetizer = packetizer
        udp.send(packet)
    }

    private func send(_ message: VoiceGatewayOutgoing) async throws {
        try await socket?.send(message.frame())
    }

    private func startHeartbeat(interval: TimeInterval) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                guard !Task.isCancelled else { return }
                await self?.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() async {
        let nonce = Int(Date().timeIntervalSince1970 * 1000)
        try? await send(session.heartbeat(nonce: nonce))
    }

    private static func describe(_ message: VoiceGatewayIncoming) -> String {
        switch message {
        case .daveExternalSender(let data): return "external sender (\(data.count) bytes)"
        case .daveProposals(let data): return "proposals (\(data.count) bytes)"
        case let .daveAnnounceCommitTransition(id, data): return "commit transition \(id) (\(data.count) bytes)"
        case let .daveWelcome(id, data): return "welcome transition \(id) (\(data.count) bytes)"
        default: return "\(message)"
        }
    }

    private static func describe(_ message: VoiceGatewayOutgoing) -> String {
        switch message {
        case .daveKeyPackage(let data): return "key package (\(data.count) bytes)"
        case .daveCommitWelcome(let data): return "commit/welcome (\(data.count) bytes)"
        default: return "\(message)"
        }
    }

    private func finish(with error: Error) {
        status = .closed
        closeError = error
        heartbeatTask?.cancel()
        eventsTask?.cancel()
        socket?.close()
        udp?.close()
        socket = nil
        udp = nil
        readiness?.resume(throwing: error)
        readiness = nil
    }
}
