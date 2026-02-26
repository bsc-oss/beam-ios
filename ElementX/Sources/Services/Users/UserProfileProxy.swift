//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

// PG_CHANGED - adds custom profile fields
struct UserProfileProxy: Equatable, Hashable, PgUserDescribing {
    let userID: String
    let displayName: String?
    let avatarURL: URL?
    let email: String?
    let department: String?
    let function: String?
    // PG_CHANGED - replaced hasPhoneBookConsent: Bool? with phoneBookConsentType
    let phoneBookConsentType: PhoneBookConsentType?
    let isProfileInitialized: Bool?
    
    init(userID: String,
         displayName: String? = nil,
         avatarURL: URL? = nil,
         email: String? = nil,
         department: String? = nil,
         function: String? = nil,
         phoneBookConsentType: PhoneBookConsentType? = nil,
         isProfileInitialized: Bool? = nil) {
        self.userID = userID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.email = email
        self.department = department
        self.function = function
        self.phoneBookConsentType = phoneBookConsentType
        self.isProfileInitialized = isProfileInitialized
    }
    
    init(member: RoomMemberDetails) {
        userID = member.id
        displayName = member.isBanned ? nil : member.name
        avatarURL = member.isBanned ? nil : member.avatarURL
        email = member.isBanned ? nil : member.email
        department = member.isBanned ? nil : member.department
        function = member.isBanned ? nil : member.function
        phoneBookConsentType = nil
        isProfileInitialized = nil
    }
    
    init(sender: TimelineItemSender) {
        userID = sender.id
        displayName = sender.displayName
        avatarURL = sender.avatarURL
        email = sender.email
        // Department and function fields are not supported in TimelineItemSender
        department = nil
        function = nil
        phoneBookConsentType = nil
        isProfileInitialized = nil
    }
    
    init(sdkUserProfile: MatrixRustSDK.UserProfile) {
        userID = sdkUserProfile.userId
        displayName = sdkUserProfile.displayName
        avatarURL = sdkUserProfile.avatarUrl.flatMap(URL.init(string:))
        email = sdkUserProfile.email
        department = sdkUserProfile.department
        function = sdkUserProfile.function
        // PG_CHANGED - convert SDK FfiPhoneBookConsent enum to PhoneBookConsentType
        phoneBookConsentType = sdkUserProfile.phoneBookConsentType.flatMap { PhoneBookConsentType(ffiConsent: $0) }
        isProfileInitialized = sdkUserProfile.isProfileInitialized
    }
    
    init(sdkRoomHero: MatrixRustSDK.RoomHero) {
        userID = sdkRoomHero.userId
        displayName = sdkRoomHero.displayName
        avatarURL = sdkRoomHero.avatarUrl.flatMap(URL.init(string:))
        email = sdkRoomHero.email
        // Department and function fields are not supported in RoomHero
        department = nil
        function = nil
        phoneBookConsentType = nil
        isProfileInitialized = nil
    }
    
    /// A user is meant to be "verified" when the GET profile returns back either the display name or the avatar
    /// If isn't we aren't sure that the related matrix id really exists.
    var isVerified: Bool {
        displayName != nil || avatarURL != nil
    }
}

struct SearchUsersResultsProxy {
    let results: [UserProfileProxy]
    let limited: Bool
}

extension SearchUsersResultsProxy {
    init(sdkResults: MatrixRustSDK.SearchUsersResults) {
        results = sdkResults.results.map(UserProfileProxy.init)
        limited = sdkResults.limited
    }
}

extension UserProfileProxy: Identifiable {
    var id: String { userID }
}
