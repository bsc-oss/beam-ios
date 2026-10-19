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

import Compound
import MatrixRustSDK
import SwiftUI

struct UserProfileListRow: View {
    let user: UserProfile
    let membership: MembershipState?
    let mediaProvider: MediaProviderProtocol?
    
    let kind: ListRow<LoadableAvatarImage, EmptyView, EmptyView, Bool>.Kind<EmptyView, Bool>
    // PG_CHANGED - marks people already in a room with the user
    var isFromExistingChat = false
    
    var isUnknownProfile: Bool {
        !user.isVerified && membership == nil
    }
    
    private var subtitle: String? {
        guard !isUnknownProfile else { return L10n.commonInviteUnknownProfile }
        
        if let membershipText = membership?.localizedDescription {
            return membershipText
        } else {
            // PG_CHANGED
            return user.secondaryInfo
        }
    }
    
    var body: some View {
        // PG_CHANGED - email-based identity
        ListRow(label: .avatar(title: user.primaryInfo,
                               description: subtitle,
                               icon: avatar,
                               role: isUnknownProfile ? .error : nil,
                               // PG_CHANGED
                               caption: isFromExistingChat ? L10n.pgCommonSearchResultFromExistingChat : nil,
                               captionIcon: \.chat),
                kind: kind)
    }
    
    var avatar: LoadableAvatarImage {
        LoadableAvatarImage(url: user.avatarURL,
                            name: user.displayName,
                            // PG_CHANGED
                            email: user.email,
                            contentID: user.id,
                            avatarSize: .user(on: .startChat),
                            mediaProvider: mediaProvider)
    }
}

private extension MembershipState {
    var localizedDescription: String? {
        switch self {
        case .join:
            return L10n.screenInviteUsersAlreadyAMember
        case .invite:
            return L10n.screenInviteUsersAlreadyInvited
        default:
            return nil
        }
    }
}

// PG_CHANGED - a user discovery section's header: its title, or the notice about cache-only results
struct UserDiscoverySectionHeader: View {
    let section: UserDiscoverySection
    
    var body: some View {
        if let title = section.title {
            Text(title)
                .compoundListSectionHeader()
        } else if let notice = section.notice {
            Text(notice)
                .font(.compound.bodySM) // footer weight, header spacing
                .textCase(nil)
                .compoundListSectionHeader()
        }
    }
}

struct UserProfileCell_Previews: PreviewProvider, TestablePreview {
    static let action: () -> Void = { }
    
    static var previews: some View {
        Form {
            UserProfileListRow(user: .mockAlice, membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: true, action: action))
            
            UserProfileListRow(user: .mockBob, membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            UserProfileListRow(user: .mockCharlie, membership: .join, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: true, action: action))
                .disabled(true)
            
            UserProfileListRow(user: .init(userID: "@someone:matrix.org"), membership: .join, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
                .disabled(true)
            
            UserProfileListRow(user: .init(userID: "@someone:matrix.org"), membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            // PG_CHANGED
            UserProfileListRow(user: .init(userID: "@someone:matrix.org", email: "someone@matrix.org"), membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            // PG_CHANGED: user without displayName but with email
            UserProfileListRow(user: .mockBart, membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            // PG_CHANGED: user already in a chat with the account owner
            UserProfileListRow(user: .mockAlice, membership: nil, mediaProvider: MediaProviderMock(.init()),
                               kind: .multiSelection(isSelected: false, action: action),
                               isFromExistingChat: true)
        }
        .compoundList()
    }
}
