//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-08-21

import Foundation
import MatrixRustSDK

// PG_CHANGED - adds custom profile fields + PgUserDescribing (ported from the former UserProfileProxy)
nonisolated struct UserProfile: Hashable, Identifiable, PgUserDescribing {
    let id: String
    let displayName: String?
    let avatarURL: URL?
    let status: UserStatus
    // PG_CHANGED - custom profile fields
    let email: String?
    let department: String?
    let function: String?
    let phoneBookConsentType: PhoneBookConsentType?
    let isProfileInitialized: Bool?
    // PG_CHANGED - server-controlled feature flags (e.g. ["argus": true])
    let featureFlags: [String: Bool]?
    
    // PG_CHANGED - PgUserDescribing requirement
    var userID: String {
        id
    }
    
    // PG_CHANGED - adds custom profile field parameters
    init(userID: String,
         displayName: String? = nil,
         avatarURL: URL? = nil,
         status: UserStatus = .init(),
         email: String? = nil,
         department: String? = nil,
         function: String? = nil,
         phoneBookConsentType: PhoneBookConsentType? = nil,
         isProfileInitialized: Bool? = nil,
         featureFlags: [String: Bool]? = nil) {
        id = userID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.status = status
        self.email = email
        self.department = department
        self.function = function
        self.phoneBookConsentType = phoneBookConsentType
        self.isProfileInitialized = isProfileInitialized
        self.featureFlags = featureFlags
    }
    
    init(member: RoomMemberDetails) {
        id = member.id
        displayName = member.isBanned ? nil : member.name
        avatarURL = member.isBanned ? nil : member.avatarURL
        status = member.status
        // PG_CHANGED - custom profile fields
        email = member.isBanned ? nil : member.email
        department = member.isBanned ? nil : member.department
        function = member.isBanned ? nil : member.function
        phoneBookConsentType = nil
        isProfileInitialized = nil
        featureFlags = nil
    }
    
    init(sender: TimelineItemSender) {
        id = sender.id
        displayName = sender.displayName
        avatarURL = sender.avatarURL
        status = sender.status
        // PG_CHANGED - custom profile fields (department and function are not supported in TimelineItemSender)
        email = sender.email
        department = nil
        function = nil
        phoneBookConsentType = nil
        isProfileInitialized = nil
        featureFlags = nil
    }
    
    init(rustUserProfile: MatrixRustSDK.UserProfile) {
        id = rustUserProfile.userId
        displayName = rustUserProfile.displayName
        avatarURL = rustUserProfile.avatarUrl.flatMap(URL.init(string:))
        status = .init(rustStatus: rustUserProfile.status, rustCall: rustUserProfile.call)
        // PG_CHANGED - custom profile fields
        email = rustUserProfile.email
        department = rustUserProfile.department
        function = rustUserProfile.function
        phoneBookConsentType = rustUserProfile.phoneBookConsentType.flatMap { PhoneBookConsentType(ffiConsent: $0) }
        isProfileInitialized = rustUserProfile.isProfileInitialized
        featureFlags = rustUserProfile.featureFlags
    }
    
    init(rustRoomHero: MatrixRustSDK.RoomHero) {
        id = rustRoomHero.userId
        displayName = rustRoomHero.displayName
        avatarURL = rustRoomHero.avatarUrl.flatMap(URL.init(string:))
        status = .init(rustStatus: rustRoomHero.status, rustCall: rustRoomHero.call)
        // PG_CHANGED - custom profile fields (only email is supported in RoomHero)
        email = rustRoomHero.email
        department = nil
        function = nil
        phoneBookConsentType = nil
        isProfileInitialized = nil
        featureFlags = nil
    }
    
    init(member: RoomMemberProxyProtocol) {
        self.init(member: RoomMemberDetails(withProxy: member))
    }
    
    /// A user is meant to be "verified" when the GET profile returns back either the display name or the avatar
    /// If isn't we aren't sure that the related matrix id really exists.
    var isVerified: Bool {
        displayName != nil || avatarURL != nil
    }
    
    // PG_CHANGED - true when the server grants the Argus feature for this user
    var isArgusFeatureGranted: Bool {
        featureFlags?["argus"] == true
    }
}

// MARK: - Status

/// A user's status, created from a combination of their manually set status along with the call status indicator.
nonisolated struct UserStatus: Hashable {
    /// The raw status that is manually set by the user (if any).
    let raw: Raw?
    /// The call status indicator automatically set by Element Call (while in a call).
    let call: Call?
    
    /// The status that should be displayed on the user's profile.
    var displayed: Displayed? {
        // The user-set status takes precedence over the call indicator.
        raw.map { .userSet($0) } ?? call.map { .inCall($0) }
    }
    
    /// A status that is manually set by the user.
    nonisolated struct Raw: Hashable {
        let text: String
        let emoji: Character
    }
    
    /// The call status indicator automatically set by Element Call.
    nonisolated struct Call: Hashable {
        /// When the user joined the call, if known.
        let joinedDate: Date?
    }
    
    /// The status displayed in the UI.
    nonisolated enum Displayed: Hashable {
        case userSet(Raw)
        case inCall(Call)
        
        var text: String {
            switch self {
            case .userSet(let userSet): userSet.text
            case .inCall: L10n.commonOnACall
            }
        }
        
        var emoji: Character {
            switch self {
            case .userSet(let userSet): userSet.emoji
            case .inCall: "🎧"
            }
        }
    }
}

nonisolated extension UserStatus {
    init() {
        raw = nil
        call = nil
    }
    
    init(rustStatus: MatrixRustSDK.UserStatus?, rustCall: MatrixRustSDK.UserCall?) {
        raw = rustStatus.map(Raw.init)
        call = rustCall.map(Call.init)
    }
}

nonisolated extension UserStatus.Raw {
    init(rustStatus: MatrixRustSDK.UserStatus) {
        text = rustStatus.text
        emoji = Character(rustStatus.emoji)
    }
    
    // periphery:ignore - might be useful to have
    var rustValue: MatrixRustSDK.UserStatus {
        .init(emoji: String(emoji), text: text)
    }
}

nonisolated extension UserStatus.Call {
    init(rustCall: MatrixRustSDK.UserCall) {
        joinedDate = rustCall.callJoinedTs.map { Date(timeIntervalSince1970: Double($0)) }
    }
    
    // periphery:ignore - might be useful to have
    var rustValue: MatrixRustSDK.UserCall {
        .init(callJoinedTs: joinedDate.map { UInt64($0.timeIntervalSince1970) })
    }
}

// MARK: - Search Results

struct SearchUsersResults {
    var results: [UserProfile] // PG_CHANGED - var, so the service can replace it and keep the other fields
    // periphery:ignore - documents the schema, parsed but not consumed yet
    var limited = false
    // PG_CHANGED - users the client already shares a joined room with, whoever found them
    var knownFromRoomUserIDs: Set<String> = []
    // PG_CHANGED - set when the homeserver did not answer, so `results` only holds what the local cache knew
    var serverError: SearchUsersServerError?
}

extension SearchUsersResults {
    init(rustResults: MatrixRustSDK.SearchUsersResults) {
        // PG_CHANGED
        results = rustResults.results.map { UserProfile(rustUserProfile: $0.profile) }
        limited = rustResults.limited
        knownFromRoomUserIDs = Set(rustResults.results.filter(\.knownFromRoom).map(\.profile.userId))
        serverError = rustResults.serverError.map(SearchUsersServerError.init)
    }
}

// PG_CHANGED
enum SearchUsersServerError {
    case rateLimited
    /// Offline, a server error or an unmapped error kind: the search failed for a reason we cannot name.
    case unavailable
    
    init(rustError: MatrixRustSDK.SearchUsersServerError) {
        self = if case .limitExceeded = rustError.kind {
            .rateLimited
        } else {
            .unavailable
        }
    }
}
