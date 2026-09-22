//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import MatrixRustSDK
import SwiftUI

struct TimelineItemKeyForwarder: Identifiable, Hashable {
    let id: String
    let displayName: String?
    
    init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName
    }
    
    init(forwarderID: String, forwarderProfile: ProfileDetails) {
        switch forwarderProfile {
        // PG_CHANGED
        case let .ready(displayName, _, _, _):
            self.init(id: forwarderID,
                      displayName: displayName)
        default:
            self.init(id: forwarderID,
                      displayName: nil)
        }
    }
    
    var message: String {
        if let displayName {
            L10n.cryptoEventKeyForwardedKnownProfileDialogContent(displayName, id)
        } else {
            L10n.cryptoEventKeyForwardedUnknownProfileDialogContent(id)
        }
    }
}
