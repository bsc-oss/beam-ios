//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-09-11

import MatrixRustSDK

extension RoomProtocol {
    func joinCallIntent(voiceOnly: Bool = false) async -> Intent {
        switch await (hasActiveRoomCall(), isDirect()) {
        case (true, true): voiceOnly ? .joinExistingDmVoice : .joinExistingDm
        case (true, false): .joinExisting
        case (false, true): voiceOnly ? .startCallDmVoice : .startCallDm
        // PG_CHANGED - start voice call for groups
        case (false, false): .startCallVoice
        }
    }
}
