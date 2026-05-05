//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import MatrixRustSDK

extension RoomProtocol {
    var joinCallIntent: Intent {
        get async {
            switch await (hasActiveRoomCall(), isDirect()) {
            case (true, true): .joinExistingDmVoice // PG_CHANGED - TO undo when native video & voice support is available (two seperate icons)
            case (true, false): .joinExisting
            case (false, true): .startCallDmVoice // PG_CHANGED - TO undo when native video & voice support is available (two seperate icons)
            case (false, false): .startCall
            }
        }
    }
}
