//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import MatrixRustSDK
import SwiftUI

struct UserProfileListRow: View {
    let user: UserProfileProxy
    let membership: MembershipState?
    let mediaProvider: MediaProviderProtocol?
    
    let kind: ListRow<LoadableAvatarImage, EmptyView, EmptyView, Bool>.Kind<EmptyView, Bool>
    
    var isUnknownProfile: Bool { !user.isVerified && membership == nil }
    
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
        // PG_CHANGED
        ListRow(label: .avatar(title: user.primaryInfo,
                               description: subtitle,
                               icon: avatar,
                               role: isUnknownProfile ? .error : nil),
                kind: kind)
    }
    
    var avatar: LoadableAvatarImage {
        LoadableAvatarImage(url: user.avatarURL,
                            name: user.displayName,
                            // PG_CHANGED
                            email: user.email,
                            contentID: user.userID,
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

struct UserProfileCell_Previews: PreviewProvider, TestablePreview {
    static let action: () -> Void = { }
    
    static var previews: some View {
        Form {
            UserProfileListRow(user: .mockAlice, membership: nil, mediaProvider: MediaProviderMock(configuration: .init()),
                               kind: .multiSelection(isSelected: true, action: action))
            
            UserProfileListRow(user: .mockBob, membership: nil, mediaProvider: MediaProviderMock(configuration: .init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            UserProfileListRow(user: .mockCharlie, membership: .join, mediaProvider: MediaProviderMock(configuration: .init()),
                               kind: .multiSelection(isSelected: true, action: action))
                .disabled(true)
            
            UserProfileListRow(user: .init(userID: "@someone:matrix.org"), membership: .join, mediaProvider: MediaProviderMock(configuration: .init()),
                               kind: .multiSelection(isSelected: false, action: action))
                .disabled(true)
            
            UserProfileListRow(user: .init(userID: "@someone:matrix.org"), membership: nil, mediaProvider: MediaProviderMock(configuration: .init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            // PG_CHANGED
            UserProfileListRow(user: .init(userID: "@someone:matrix.org", email: "someone@matrix.org"), membership: nil, mediaProvider: MediaProviderMock(configuration: .init()),
                               kind: .multiSelection(isSelected: false, action: action))
            
            // PG_CHANGED: user without displayName but with email
            UserProfileListRow(user: .mockBart, membership: nil, mediaProvider: MediaProviderMock(configuration: .init()),
                               kind: .multiSelection(isSelected: false, action: action))
        }
        .compoundList()
    }
}
