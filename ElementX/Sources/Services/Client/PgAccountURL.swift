//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

extension ClientProxyProtocol {
    /// The account management URL for `action`, telling the page which device we are.
    ///
    /// Use this rather than `accountURL(action:)` for anything the user opens, so every way into the page behaves the same.
    func pgAccountURL(action: AccountManagementAction) async -> URL? {
        guard let url = await accountURL(action: action) else { return nil }
        guard let deviceID else { return url }
        return url.appendingPgCurrentDeviceID(deviceID)
    }
}

extension URL {
    /// Beam's account provider (MAS) reads this parameter to mark our own entry in its device list, so the user doesn't
    /// sign the wrong device out. Other account providers ignore parameters they don't know.
    func appendingPgCurrentDeviceID(_ deviceID: String) -> URL {
        appending(queryItems: [URLQueryItem(name: "pg_current_device_id", value: deviceID)])
    }
}
