//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import MatrixRustSDK
import SwiftUI

struct TimelineItemSender: Identifiable, Hashable, PgUserDescribing {
    static let test = TimelineItemSender(id: "@test.matrix.org")
    
    let id: String
    // PG_CHANGED
    var userID: String { id }
    let displayName: String?
    // PG_CHANGED
    let email: String?
    let isDisplayNameAmbiguous: Bool
    let avatarURL: URL?
    
    // PG_CHANGED
    init(id: String, displayName: String? = nil, email: String? = nil, isDisplayNameAmbiguous: Bool = false, avatarURL: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.isDisplayNameAmbiguous = isDisplayNameAmbiguous
        self.avatarURL = avatarURL
        // PG_CHANGED
        self.email = email
    }
    
    init(senderID: String, senderProfile: ProfileDetails) {
        switch senderProfile {
        // PG_CHANGED
        case let .ready(displayName, isDisplayNameAmbiguous, avatarUrl, email):
            self.init(id: senderID,
                      displayName: displayName,
                      // PG_CHANGED
                      email: email,
                      isDisplayNameAmbiguous: isDisplayNameAmbiguous,
                      avatarURL: avatarUrl.flatMap(URL.init(string:)))
        default:
            self.init(id: senderID,
                      displayName: nil,
                      // PG_CHANGED
                      email: nil,
                      isDisplayNameAmbiguous: false,
                      avatarURL: nil)
        }
    }
        
    var disambiguatedDisplayName: String? {
        guard let displayName else {
            return nil
        }
        
        // PG_CHANGED
        return isDisplayNameAmbiguous ? "\(displayName) (\(emailOrId))" : displayName
    }
}
