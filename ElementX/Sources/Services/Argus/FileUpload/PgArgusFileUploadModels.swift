//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct PgArgusUploadFilePayload: Decodable {
    let uri: String?
    let path: String?
    let mimeType: String?
    let fileName: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case uri, path, mimeType, fileName
    }

    /// Property names consumed locally to resolve the file bytes and the multipart `file` part.
    /// Derived from ``CodingKeys`` so the DTO stays the single source of truth. Every other key in
    /// the payload is forwarded as an extra multipart string form field (see ``PgArgusFileUploadHandler``).
    static let reservedKeys = Set(CodingKeys.allCases.map(\.rawValue))
}
