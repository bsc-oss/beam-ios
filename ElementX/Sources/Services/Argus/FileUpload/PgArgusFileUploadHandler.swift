//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

struct PgArgusFileUploadHandler {
    private let clientProxy: ClientProxyProtocol
    
    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
    }
    
    func handle(_ envelope: PgArgusBridgeEnvelope) async -> PgArgusBridgeResponse {
        do {
            guard let payloadString = envelope.payload else {
                throw PgArgusBridgeError.missingPayload
            }
            
            let payloadData = Data(payloadString.utf8)
            let payload = try JSONDecoder().decode(PgArgusUploadFilePayload.self, from: payloadData)
            let sourceURL = try resolveFileURL(for: payload)
            let mimeType = payload.mimeType ?? "application/octet-stream"
            
            // iOS camera captures declared as MP4 are really QuickTime files (see the rewrapper);
            // upload a rewrapped temporary copy in their place and drop it once the upload settles.
            let rewrappedURL = try await PgArgusVideoContainerRewrapper.mp4Copy(of: sourceURL, declaredMimeType: mimeType)
            defer {
                if let rewrappedURL {
                    try? FileManager.default.removeItem(at: rewrappedURL)
                }
            }
            let fileURL = rewrappedURL ?? sourceURL
            
            let mediaInfo = MediaInfo.file(fileURL: fileURL,
                                           fileInfo: FileInfo(mimetype: mimeType,
                                                              size: fileSize(at: fileURL),
                                                              thumbnailInfo: nil,
                                                              thumbnailSource: nil))
            
            let fields = extraFields(from: payloadData)
            let fileID = try await clientProxy.uploadArgusFile(mediaInfo, fileName: payload.fileName, fields: fields).get()
            MXLog.info("Argus uploadFile succeeded")
            return PgArgusBridgeResponse(type: PgArgusFeature.uploadFile.responseType,
                                         requestID: envelope.requestID,
                                         fileID: fileID)
        } catch {
            MXLog.error("Argus uploadFile failed: \(error)")
            return envelope.errorResponse(error.localizedDescription)
        }
    }
    
    /// Every non-reserved scalar key in the payload is forwarded as an extra multipart string form
    /// field. Nested objects, arrays and `null` are dropped — they cannot become form fields.
    private func extraFields(from payloadData: Data) -> [String: String] {
        guard let object = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return [:]
        }
        return object.reduce(into: [String: String]()) { result, entry in
            guard !PgArgusUploadFilePayload.reservedKeys.contains(entry.key),
                  let value = Self.scalarString(entry.value) else {
                return
            }
            result[entry.key] = value
        }
    }
    
    private static func scalarString(_ value: Any) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            // CFBoolean bridges to NSNumber; render as true/false to match the source JSON scalar.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        default:
            return nil
        }
    }
    
    private func resolveFileURL(for payload: PgArgusUploadFilePayload) throws -> URL {
        let url: URL
        if let path = payload.path, !path.isEmpty {
            url = URL(fileURLWithPath: path)
        } else if let uri = payload.uri, !uri.isEmpty,
                  let parsed = URL(string: uri), parsed.isFileURL {
            url = parsed
        } else {
            throw PgArgusBridgeError.invalidFileURL
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PgArgusBridgeError.fileNotFound(url)
        }
        return url
    }
    
    private func fileSize(at url: URL) -> UInt64? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize.map(UInt64.init)
    }
}
