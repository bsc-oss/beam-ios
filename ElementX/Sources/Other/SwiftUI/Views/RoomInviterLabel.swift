//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct RoomInviterDetails: Equatable, PgUserDescribing {
    let id: String
    // PG_CHANGED - exposing id also as userID to conform to PgUserDescribing protocol
    var userID: String { id }
    let displayName: String?
    // PG_CHANGED
    let email: String?
    let avatarURL: URL?
    
    let attributedInviteText: AttributedString
    
    init(member: RoomMemberProxyProtocol) {
        id = member.userID
        displayName = member.displayName
        // PG_CHANGED
        email = member.email
        avatarURL = member.avatarURL
        
        // Pre-compute the attributed string.
        let placeholder = "{displayname}"
        
        // PG_CHANGED
        var string = AttributedString(L10n.screenInvitesInvitedYou(placeholder, member.secondaryInfo ?? id))
        var displayNameString = AttributedString(member.primaryInfo)
        
        displayNameString.bold()
        displayNameString.foregroundColor = .compound.textPrimary
        string.replace(placeholder, with: displayNameString)
        attributedInviteText = string
    }
}

struct RoomInviterLabel: View {
    let inviter: RoomInviterDetails
    var shouldHideAvatar = false
    
    let mediaProvider: MediaProviderProtocol?
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            LoadableAvatarImage(url: shouldHideAvatar ? nil : inviter.avatarURL,
                                name: inviter.displayName,
                                // PG_CHANGED
                                email: inviter.email,
                                contentID: inviter.id,
                                avatarSize: .custom(16),
                                mediaProvider: mediaProvider)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] * 0.8 }
                .accessibilityHidden(true)
            
            Text(inviter.attributedInviteText)
        }
    }
}

// MARK: - Previews

struct RoomInviterLabel_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(spacing: 10) {
            RoomInviterLabel(inviter: .init(member: RoomMemberProxyMock.mockAlice),
                             mediaProvider: MediaProviderMock(configuration: .init()))
            RoomInviterLabel(inviter: .init(member: RoomMemberProxyMock.mockDan),
                             mediaProvider: MediaProviderMock(configuration: .init()))
            RoomInviterLabel(inviter: .init(member: RoomMemberProxyMock.mockNoName),
                             mediaProvider: MediaProviderMock(configuration: .init()))
            // PG_CHANGED
            RoomInviterLabel(inviter: .init(member: RoomMemberProxyMock.mockBart),
                             mediaProvider: MediaProviderMock(configuration: .init()))
            RoomInviterLabel(inviter: .init(member: RoomMemberProxyMock.mockAnna),
                             mediaProvider: MediaProviderMock(configuration: .init()))
            
            RoomInviterLabel(inviter: .init(member: RoomMemberProxyMock.mockCharlie),
                             mediaProvider: MediaProviderMock(configuration: .init()))
                .foregroundStyle(.compound.textPrimary)
        }
        .font(.compound.bodyMD)
        .foregroundStyle(.compound.textSecondary)
    }
}
