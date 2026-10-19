//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Foundation
import MatrixRustSDK

// PG_CHANGED
// sourcery: AutoMockable
// PG_CHANGED - adds PgUserDescribing
nonisolated protocol RoomMemberProxyProtocol: AnyObject, Sendable, PgUserDescribing {
    var userID: String { get }
    
    var displayName: String? { get }
    var disambiguatedDisplayName: String? { get }
    var avatarURL: URL? { get }
    var status: UserStatus { get }
    
    var membership: MembershipState { get }
    
    var membershipChangeReason: String? { get }
    
    var isIgnored: Bool { get }
    
    var powerLevel: RoomPowerLevel { get }
    
    // PG_CHANGED
    
    var department: String? { get }
    
    var function: String? { get }
    
    var email: String? { get }
    // periphery:ignore - might be useful to have
    var isServiceMember: Bool { get }
}

nonisolated extension RoomMemberProxyProtocol {
    /// The member is active in the room (joined or invited).
    var isActive: Bool {
        membership == .join || membership == .invite || membership == .knock
    }
    
    var permalink: URL? {
        try? URL(string: matrixToUserPermalink(userId: userID))
    }
    
    /// The name used for sorting the member alphabetically. This will be the displayname if,
    /// it exists otherwise it will be the userID with the leading `@` removed.
    var sortingName: String {
        // If there isn't a displayname we sort by the userID without the @.
        // PG_CHANGED
        (displayName ?? email ?? String(userID.dropFirst())).lowercased()
    }
}

nonisolated extension [RoomMemberProxyProtocol] {
    /// The members, sorted first by call participation, then by power-level, and then alphabetically within each power-level.
    func sorted(prioritisingRoomCallParticipants roomCallParticipants: [String] = []) -> Self {
        sorted { lhs, rhs in
            let lhsIsRoomCallParticipant = roomCallParticipants.contains(lhs.userID)
            let rhsIsRoomCallParticipant = roomCallParticipants.contains(rhs.userID)
            
            return if lhsIsRoomCallParticipant != rhsIsRoomCallParticipant {
                lhsIsRoomCallParticipant
            } else if lhs.powerLevel != rhs.powerLevel {
                lhs.powerLevel > rhs.powerLevel
            } else {
                lhs.sortingName.localizedStandardCompare(rhs.sortingName) == .orderedAscending
            }
        }
    }
}

nonisolated extension RoomMemberProxyProtocol {
    var role: RoomRole {
        .init(powerLevel: powerLevel)
    }
}
