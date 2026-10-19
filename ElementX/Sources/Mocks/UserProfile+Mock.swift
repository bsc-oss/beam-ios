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

import Foundation

extension UserProfile {
    /// Mocks
    // PG_CHANGED - adds the custom profile fields
    static var mockAlice: UserProfile {
        .init(userID: "@alice:matrix.org",
              displayName: "Alice",
              avatarURL: "mxc://matrix.org/UcCimidcvpFvWkPzvjXMQPHA",
              email: "alice@matrix.org",
              department: "Engineering",
              function: "Engineer")
    }
    
    // PG_CHANGED: adds a user without displayName and with email
    static var mockBart: UserProfile {
        .init(userID: "@bart:matrix.org", avatarURL: "mxc://matrix.org/UcCimidcvpFvWkPzvjXMQPHA", email: "bart@matrix.org")
    }
    
    static var mockBob: UserProfile {
        .init(userID: "@bob:matrix.org", displayName: "Bob", avatarURL: nil)
    }
    
    static var mockBobby: UserProfile {
        .init(userID: "@bobby:matrix.org", displayName: "Bobby", avatarURL: nil)
    }
    
    static var mockCharlie: UserProfile {
        .init(userID: "@charlie:matrix.org", displayName: "Charlie", avatarURL: nil)
    }
    
    static var mockDan: UserProfile {
        .init(userID: "@dan:matrix.org", displayName: "Dan", avatarURL: .mockMXCUserAvatar)
    }
    
    static var mockErin: UserProfile {
        .init(userID: "@erin:matrix.org", displayName: "Erin", status: .mockFocussing)
    }
    
    static var mockFrank: UserProfile {
        .init(userID: "@frank:matrix.org", displayName: "Frank", status: .mockCall)
    }
    
    static var mockVerbose: UserProfile {
        .init(userID: "@charlie:matrix.org", displayName: "Charlie is the best display name", avatarURL: nil)
    }
}

nonisolated extension UserStatus {
    static var mockCall: UserStatus {
        .init(raw: nil, call: .init(joinedDate: nil))
    }
    
    static var mockFocussing: UserStatus {
        .init(raw: .init(text: "Focussing", emoji: "🧑‍💻"), call: nil)
    }
    
    static var mockHoliday: UserStatus {
        .init(raw: .init(text: "Holiday", emoji: "🏝️"), call: nil)
    }
    
    static func mock(text: String, emoji: Character) -> UserStatus {
        .init(raw: .init(text: text, emoji: emoji), call: nil)
    }
}
