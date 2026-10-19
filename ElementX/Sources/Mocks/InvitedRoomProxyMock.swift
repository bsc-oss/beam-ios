//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Combine
import Foundation
import MatrixRustSDK

@MainActor
struct InvitedRoomProxyMockConfiguration {
    var id = UUID().uuidString
    var name: String?
    var avatarURL: URL?
    var isSpace = false
    var members: [RoomMemberProxyMock] = .allMembers
    var inviter: RoomMemberProxyMock = .mockAlice
}

extension InvitedRoomProxyMock {
    @MainActor
    convenience init(_ configuration: InvitedRoomProxyMockConfiguration) {
        self.init()
        id = configuration.id
        info = RoomInfoProxyMock(configuration)
        inviter = configuration.inviter
        
        rejectInvitationReturnValue = .success(())
    }
}

extension RoomInfoProxyMock {
    @MainActor convenience init(_ configuration: InvitedRoomProxyMockConfiguration) {
        self.init()
        
        id = configuration.id
        isEncrypted = false
        displayName = configuration.name
        topic = nil
        
        avatarURL = configuration.avatarURL
        
        isDirect = false
        isSpace = configuration.isSpace
        successor = nil
        isFavourite = false
        canonicalAlias = nil
        alternativeAliases = []
        membership = .knocked
        heroes = []
        activeMembersCount = configuration.members.filter { $0.membership == .join || $0.membership == .invite }.count
        joinedMembersCount = configuration.members.filter { $0.membership == .join }.count
        // PG_CHANGED - upstream no longer assigns the badge counts here; PG keeps hasOtherJoinedMember (consumed by PG invited-room UI)
        hasOtherJoinedMember = configuration.members.filter { $0.membership == .join && $0.userID != RoomMemberProxyMock.mockMe.userID }.count > 0
        hasRoomCall = false
        activeRoomCallParticipants = []
        pinnedEventIDs = []
        joinRule = .invite
        historyVisibility = .shared
        
        powerLevels = RoomPowerLevelsProxyMock(.init())
    }
}

private extension RoomMember {
    init(_ proxy: RoomMemberProxyProtocol) {
        self.init(userId: proxy.userID,
                  displayName: proxy.displayName,
                  avatarUrl: proxy.avatarURL?.absoluteString,
                  status: proxy.status.raw?.rustValue,
                  call: proxy.status.call?.rustValue,
                  membership: proxy.membership,
                  isNameAmbiguous: proxy.disambiguatedDisplayName != proxy.displayName,
                  powerLevel: proxy.powerLevel.rustPowerLevel,
                  isIgnored: proxy.isIgnored,
                  suggestedRoleForPowerLevel: proxy.role.rustRole,
                  membershipChangeReason: proxy.membershipChangeReason,
                  isServiceMember: proxy.isServiceMember,
                  // PG_CHANGED
                  department: proxy.department,
                  function: proxy.function,
                  email: proxy.email)
    }
}
