//
//  LibDAVECrypto.swift
//  DiscordKit
//
//  Created by Михаил Гудзикевич on 09.10.2026
//

import Foundation
import CDave

public final class LibDAVECrypto: DAVECrypto {

    //MARK: - Properties

    public var maxProtocolVersion: Int { Int(daveMaxSupportedProtocolVersion()) }

    private let session: DAVESessionHandle
    private let encryptor: DAVEEncryptorHandle
    private var selfUserID = ""
    private var assignedSSRC: UInt32?

    //MARK: - Init

    public init?() {
        guard let session = daveSessionCreate(nil, nil, nil, nil) else { return nil }
        guard let encryptor = daveEncryptorCreate() else {
            daveSessionDestroy(session)
            return nil
        }
        self.session = session
        self.encryptor = encryptor
        daveEncryptorSetPassthroughMode(encryptor, true)
    }

    deinit {
        daveEncryptorDestroy(encryptor)
        daveSessionDestroy(session)
    }

    //MARK: - Public methods

    public func reinit(protocolVersion: Int, groupID: UInt64, selfUserID: String) {
        self.selfUserID = selfUserID
        daveSessionInit(session, UInt16(protocolVersion), groupID, selfUserID)
    }

    public func reset() {
        daveSessionReset(session)
    }

    public func setExternalSender(_ externalSender: Data) {
        externalSender.withUnsafeBytes { buffer in
            daveSessionSetExternalSender(session, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count)
        }
    }

    public func keyPackage() -> Data {
        takeBuffer { daveSessionGetMarshalledKeyPackage(session, $0, $1) } ?? Data()
    }

    public func processProposals(_ payload: Data, recognizedUserIDs: Set<String>) -> Data? {
        withCStrings(recognizedUserIDs) { ids, count in
            payload.withUnsafeBytes { buffer in
                takeBuffer {
                    daveSessionProcessProposals(session, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count, ids, count, $0, $1)
                }
            }
        }
    }

    public func processCommit(_ commit: Data) -> DAVECommitOutcome {
        let result = commit.withUnsafeBytes { buffer in
            daveSessionProcessCommit(session, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count)
        }
        guard let result else { return .failed }
        defer { daveCommitResultDestroy(result) }
        if daveCommitResultIsFailed(result) { return .failed }
        if daveCommitResultIsIgnored(result) { return .ignored }
        return .accepted
    }

    public func processWelcome(_ welcome: Data, recognizedUserIDs: Set<String>) -> Bool {
        let result = withCStrings(recognizedUserIDs) { ids, count in
            welcome.withUnsafeBytes { buffer in
                daveSessionProcessWelcome(session, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count, ids, count)
            }
        }
        guard let result else { return false }
        daveWelcomeResultDestroy(result)
        return true
    }

    public func useLatestKeyRatchet() {
        guard let ratchet = daveSessionGetKeyRatchet(session, selfUserID) else { return }
        daveEncryptorSetKeyRatchet(encryptor, ratchet)
        daveKeyRatchetDestroy(ratchet)
    }

    public func setPassthrough(_ enabled: Bool) {
        daveEncryptorSetPassthroughMode(encryptor, enabled)
    }

    public func encrypt(_ frame: Data, ssrc: UInt32) -> Data? {
        if assignedSSRC != ssrc {
            daveEncryptorAssignSsrcToCodec(encryptor, ssrc, DAVE_CODEC_OPUS)
            assignedSSRC = ssrc
        }
        let capacity = daveEncryptorGetMaxCiphertextByteSize(encryptor, DAVE_MEDIA_TYPE_AUDIO, frame.count)
        var output = Data(count: capacity)
        var written = 0
        let code = frame.withUnsafeBytes { input in
            output.withUnsafeMutableBytes { out in
                daveEncryptorEncrypt(
                    encryptor, DAVE_MEDIA_TYPE_AUDIO, ssrc,
                    input.bindMemory(to: UInt8.self).baseAddress, input.count,
                    out.bindMemory(to: UInt8.self).baseAddress, capacity, &written
                )
            }
        }
        guard code == DAVE_ENCRYPTOR_RESULT_CODE_SUCCESS else { return nil }
        return output.prefix(written)
    }

    //MARK: - Private methods

    private func takeBuffer(_ fill: (UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, UnsafeMutablePointer<Int>) -> Void) -> Data? {
        var pointer: UnsafeMutablePointer<UInt8>?
        var length = 0
        fill(&pointer, &length)
        guard let pointer else { return nil }
        defer { daveFree(pointer) }
        return Data(bytes: pointer, count: length)
    }

    private func withCStrings<Result>(_ strings: Set<String>, _ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?, Int) -> Result) -> Result {
        let copies = strings.map { strdup($0) }
        defer { copies.forEach { free($0) } }
        var pointers = copies.map { UnsafePointer($0) }
        return pointers.withUnsafeMutableBufferPointer { buffer in
            body(buffer.baseAddress, buffer.count)
        }
    }
}
