//
//  VoiceWebSocket.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation

public final class VoiceWebSocket: NSObject {

    //MARK: - Properties

    public enum Event: Equatable {
        case opened
        case text(String)
        case binary(Data)
        case closed(code: Int)
    }

    public let events: AsyncStream<Event>

    private let url: URL
    private let continuation: AsyncStream<Event>.Continuation
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private let lock = NSLock()
    private var didFinish = false

    //MARK: - Init

    public init(url: URL) {
        self.url = url
        (events, continuation) = AsyncStream.makeStream(of: Event.self)
        super.init()
    }

    //MARK: - Public methods

    public func connect() {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task
        task.resume()
        receiveNext()
    }

    public func send(_ frame: VoiceGatewayOutgoing.Frame) async throws {
        guard let task else { return }
        switch frame {
        case .text(let text): try await task.send(.string(text))
        case .binary(let data): try await task.send(.data(data))
        }
    }

    public func close(code: URLSessionWebSocketTask.CloseCode = .normalClosure) {
        task?.cancel(with: code, reason: nil)
        finish(code: code.rawValue)
    }

    //MARK: - Private methods

    private func receiveNext() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.string(let text)):
                self.continuation.yield(.text(text))
                self.receiveNext()
            case .success(.data(let data)):
                self.continuation.yield(.binary(data))
                self.receiveNext()
            case .success:
                self.receiveNext()
            case .failure:
                let code = self.task?.closeCode.rawValue ?? 0
                self.finish(code: code == 0 ? 1006 : code)
            }
        }
    }

    private func finish(code: Int) {
        lock.lock()
        let alreadyFinished = didFinish
        didFinish = true
        lock.unlock()
        guard !alreadyFinished else { return }
        continuation.yield(.closed(code: code))
        continuation.finish()
        session?.invalidateAndCancel()
    }
}

//MARK: - URLSessionWebSocketDelegate

extension VoiceWebSocket: URLSessionWebSocketDelegate {

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        continuation.yield(.opened)
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        finish(code: closeCode.rawValue)
    }
}
