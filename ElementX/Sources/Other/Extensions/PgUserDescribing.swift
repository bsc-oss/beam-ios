//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

// PG_CHANGED - Used to share user description logic among different user related structures.

protocol PgUserDescribing {
    var displayName: String? { get }
    var email: String? { get }
    var userID: String { get }
    // sourcery: AutoMockableUseDefault
    var emailOrId: String { get }
    // sourcery: AutoMockableUseDefault
    var primaryInfo: String { get }
    // sourcery: AutoMockableUseDefault
    var secondaryInfo: String? { get }
}

extension PgUserDescribing {
    var emailOrId: String {
        return if let email, !email.isEmpty {
            email
        } else {
            userID
        }
    }
    
    var primaryInfo: String {
        return if let displayName, !displayName.isEmpty {
            displayName
        } else {
            emailOrId
        }
    }
    
    var secondaryInfo: String? {
        displayName?.isEmpty == false ? emailOrId : nil
    }
}
