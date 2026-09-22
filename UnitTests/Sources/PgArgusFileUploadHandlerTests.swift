//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import Testing

@testable import ElementX

@MainActor
struct PgArgusFileUploadHandlerTests {
    @Test
    func forwardsResolvedFileWithoutExtraFields() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.uploadArgusFileFileNameFieldsReturnValue = .success("file-123")
        let fileURL = try makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let response = try #require(await handle(clientProxy: clientProxy,
                                                 requestID: "req-1",
                                                 payload: #"{"path":"\#(fileURL.path)","fileName":"icon.png","mimeType":"image/png"}"#))

        #expect(response.type == PgArgusFeature.uploadFile.responseType)
        #expect(response.requestID == "req-1")
        #expect(response.fileID == "file-123")
        #expect(response.error == nil)
        #expect(clientProxy.uploadArgusFileFileNameFieldsReceivedArguments?.fields.isEmpty == true)
    }

    @Test
    func forwardsExtraPayloadKeysAsFormFields() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.uploadArgusFileFileNameFieldsReturnValue = .success("file-123")
        let fileURL = try makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let response = try #require(await handle(clientProxy: clientProxy,
                                                 requestID: "req-fields",
                                                 payload: #"{"path":"\#(fileURL.path)","fileName":"icon.png","mimeType":"image/png","source":"Camera"}"#))

        #expect(response.fileID == "file-123")
        // The dynamic prop is forwarded; the reserved local-resolution keys are not.
        #expect(clientProxy.uploadArgusFileFileNameFieldsReceivedArguments?.fields == ["source": "Camera"])
    }

    // MARK: - Helpers

    private func handle(clientProxy: ClientProxyMock, requestID: String, payload: String) async -> PgArgusBridgeResponse? {
        let message: [String: Any?] = [
            "type": PgArgusFeature.uploadFile.requestType,
            "requestId": requestID,
            "payload": payload
        ]
        guard let envelope = PgArgusBridgeEnvelope(message: message) else { return nil }
        let handler = PgArgusFileUploadHandler(clientProxy: clientProxy)
        return await handler.handleMessage(message, envelope: envelope)
    }

    private func makeTemporaryFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1, 2, 3]).write(to: url)
        return url
    }
}
