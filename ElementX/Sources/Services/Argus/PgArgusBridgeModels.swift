//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The Argus features the brownfield bridge knows how to handle.
///
/// Each feature has a distinct request and response message type, derived from
/// the case raw value via the well-known `argus.<id>.{request,response}`
/// naming convention so the prefix and suffix only live in one place.
///
/// Decoded on the RN JavaScript thread (see `PgArgusBridge.registerListener`), so it must stay off the main actor.
nonisolated enum PgArgusFeature: String, CaseIterable {
    case uploadFile
    case reportSighting
    
    var requestType: String {
        "argus.\(rawValue).request"
    }
    
    var responseType: String {
        "argus.\(rawValue).response"
    }
    
    init?(requestType: String) {
        guard let match = Self.allCases.first(where: { $0.requestType == requestType }) else {
            return nil
        }
        self = match
    }
}

/// The `Sendable` form of a bridge message, decoded on the RN JavaScript thread before hopping to the main actor.
nonisolated struct PgArgusBridgeEnvelope {
    let type: String
    let requestID: String
    /// The feature's JSON payload, as the bundle sent it.
    let payload: String?
    
    /// The feature this envelope addresses, or `nil` for non-Argus messages.
    var feature: PgArgusFeature? {
        PgArgusFeature(requestType: type)
    }
    
    init?(message: [String: Any?]) {
        guard let type = message["type"] as? String,
              let requestID = message["requestId"] as? String else {
            return nil
        }
        
        self.type = type
        self.requestID = requestID
        payload = message["payload"] as? String
    }
    
    /// Builds an error response paired to this envelope's request type.
    func errorResponse(_ message: String) -> PgArgusBridgeResponse {
        PgArgusBridgeResponse(type: feature?.responseType ?? type,
                              requestID: requestID,
                              error: message)
    }
}

nonisolated struct PgArgusBridgeResponse {
    let type: String
    let requestID: String
    let error: String?
    let fileID: String?
    
    init(type: String,
         requestID: String,
         error: String? = nil,
         fileID: String? = nil) {
        self.type = type
        self.requestID = requestID
        self.error = error
        self.fileID = fileID
    }
    
    func toMessage() -> [String: Any?] {
        var message: [String: Any?] = [
            "type": type,
            "requestId": requestID
        ]
        
        if let error {
            message["error"] = error
        }
        if let fileID {
            message["fileId"] = fileID
        }
        return message
    }
}

enum PgArgusBridgeError: LocalizedError {
    case missingPayload
    case invalidFileURL
    case fileNotFound(URL)
    case videoRewrapFailed
    
    var errorDescription: String? {
        switch self {
        case .missingPayload:
            return "Argus payload was missing."
        case .invalidFileURL:
            return "Argus uploadFile request did not contain a valid file URL or path."
        case .fileNotFound:
            return "Argus uploadFile request pointed to a file that does not exist."
        case .videoRewrapFailed:
            return "Argus uploadFile could not rewrap the QuickTime recording as MP4."
        }
    }
}
