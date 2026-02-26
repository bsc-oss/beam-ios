//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

struct RoomMemberProxyMockConfiguration {
    var userID: String
    var displayName: String?
    // PG_CHANGED
    var email: String?
    var function: String?
    var department: String?
    
    var avatarURL: URL?
    
    var membership: MembershipState
    var isIgnored = false
    
    var powerLevel = RoomPowerLevel(value: 0)
}

extension RoomMemberProxyMock {
    convenience init(with configuration: RoomMemberProxyMockConfiguration) {
        self.init()
        userID = configuration.userID
        displayName = configuration.displayName
        
        if let displayName = configuration.displayName {
            disambiguatedDisplayName = "\(displayName) (\(userID))"
        }
        
        // PG_CHANGED
        email = configuration.email
        function = configuration.function
        department = configuration.department
        
        avatarURL = configuration.avatarURL
        
        membership = configuration.membership
        isIgnored = configuration.isIgnored
        
        powerLevel = configuration.powerLevel
    }

    // Mocks
    static var mockMe: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@me:matrix.org",
                                        displayName: "Me",
                                        // PG_CHANGED
                                        email: "me@matrix.org",
                                        function: "Case Manager",
                                        department: "Finance",
                                        avatarURL: .mockMXCUserAvatar,
                                        membership: .join))
    }
    
    static var mockMeAdmin: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@me:matrix.org",
                                        displayName: "Me",
                                        avatarURL: .mockMXCUserAvatar,
                                        membership: .join,
                                        powerLevel: .init(value: 100)))
    }
    
    static var mockMeCreator: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@me:matrix.org",
                                        displayName: "Me",
                                        avatarURL: .mockMXCUserAvatar,
                                        membership: .join,
                                        powerLevel: .infinite))
    }
    
    static var mockAlice: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@alice:matrix.org",
                                        displayName: "Alice",
                                        // PG_CHANGED
                                        email: "alice@matrix.org",
                                        function: "engineer",
                                        department: "Engineering",
                                        membership: .join))
    }
    
    // PG_CHANGED: user without displayName with email
    static var mockBart: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@bart:matrix.org",
                                        email: "bart@matrix.org",
                                        membership: .join))
    }
    
    // PG_CHANGED: user with displayName and email
    static var mockAnna: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@anna:matrix.org",
                                        displayName: "Anna",
                                        email: "anna@matrix.org",
                                        membership: .join))
    }
    
    static var mockInvitedAlice: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@alice:matrix.org",
                                        displayName: "Alice",
                                        // PG_CHANGED
                                        email: "alice@matrix.org",
                                        membership: .invite))
    }

    static var mockBob: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@bob:matrix.org",
                                        displayName: "Bob",
                                        // PG_CHANGED
                                        email: "bob@matrix.org",
                                        function: "Builder",
                                        department: "Construction",
                                        membership: .join))
    }

    static var mockCharlie: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@charlie:matrix.org",
                                        displayName: "Charlie",
                                        // PG_CHANGED
                                        email: "charlie@matrix.org",
                                        membership: .join))
    }

    static var mockDan: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@dan:matrix.org",
                                        displayName: "Dan",
                                        // PG_CHANGED
                                        email: "dan@matrix.org",
                                        avatarURL: .mockMXCUserAvatar,
                                        membership: .join))
    }
    
    static var mockVerbose: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@charliev:matrix.org",
                                        displayName: "Charlie is the best display name",
                                        // PG_CHANGED
                                        email: "charliev@matrix.org",
                                        membership: .join))
    }
    
    static var mockNoName: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@anonymous:matrix.org",
                                        membership: .join))
    }
    
    static var mockInvited: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@invited:matrix.org",
                                        displayName: "Invited",
                                        // PG_CHANGED
                                        email: "invited@matrix.org",
                                        membership: .invite,
                                        isIgnored: true))
    }

    static var mockIgnored: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@ignored:matrix.org",
                                        displayName: "Ignored",
                                        // PG_CHANGED
                                        email: "ignored@matrix.org",
                                        membership: .join,
                                        isIgnored: true))
    }
    
    static var mockAdmin: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@admin:matrix.org",
                                        displayName: "Arthur",
                                        // PG_CHANGED
                                        email: "admin@matrix.org",
                                        membership: .join,
                                        powerLevel: .init(value: 100)))
    }
    
    static var mockCreator: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@creator:matrix.org",
                                        displayName: "God",
                                        // PG_CHANGED
                                        email: "creator@matrix.org",
                                        membership: .join,
                                        powerLevel: .infinite))
    }
    
    static var mockOwner: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@owner:matrix.org",
                                        displayName: "Guinevere",
                                        // PG_CHANGED
                                        email: "owner@matrix.org",
                                        membership: .join,
                                        powerLevel: .value(150)))
    }
    
    static var mockModerator: RoomMemberProxyMock {
        RoomMemberProxyMock(with: .init(userID: "@mod:matrix.org",
                                        displayName: "Merlin",
                                        // PG_CHANGED
                                        email: "mod@matrix.org",
                                        membership: .join,
                                        powerLevel: .init(value: 50)))
    }
    
    static var mockBanned: [RoomMemberProxyMock] {
        [
            RoomMemberProxyMock(with: .init(userID: "@mischief:matrix.org",
                                            membership: .ban)),
            RoomMemberProxyMock(with: .init(userID: "@spam:matrix.org",
                                            membership: .ban)),
            RoomMemberProxyMock(with: .init(userID: "@angry:matrix.org",
                                            membership: .ban)),
            RoomMemberProxyMock(with: .init(userID: "@fake:matrix.org",
                                            displayName: "The President",
                                            membership: .ban))
        ]
    }
}

extension Array where Element == RoomMemberProxyMock {
    static let allMembers: [RoomMemberProxyMock] = [
        .mockMe,
        .mockAlice,
        .mockBob,
        .mockCharlie,
        .mockDan,
        .mockInvited,
        .mockIgnored
    ]
    
    static let allMembersAsAdmin: [RoomMemberProxyMock] = [
        .mockMeAdmin,
        .mockAlice,
        .mockBob,
        .mockCharlie,
        .mockDan,
        .mockInvited,
        .mockIgnored,
        .mockAdmin,
        .mockModerator
    ]
    
    /// This also includes the creator and the owner role.
    static let allMembersAsAdminV2: [RoomMemberProxyMock] = [
        .mockMeAdmin,
        .mockAlice,
        .mockBob,
        .mockCharlie,
        .mockDan,
        .mockInvited,
        .mockIgnored,
        .mockAdmin,
        .mockModerator,
        .mockOwner,
        .mockCreator
    ]
    
    static let allMembersAsCreator: [RoomMemberProxyMock] = [
        .mockAdmin,
        .mockAlice,
        .mockBob,
        .mockCharlie,
        .mockDan,
        .mockInvited,
        .mockIgnored,
        .mockModerator,
        .mockCreator,
        .mockMeCreator,
        .mockOwner
    ]
}
