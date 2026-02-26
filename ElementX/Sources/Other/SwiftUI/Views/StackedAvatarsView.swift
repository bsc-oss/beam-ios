//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct StackedAvatarInfo {
    let url: URL?
    let name: String?
    // PG_CHANGED
    let email: String?
    let contentID: String
}

struct StackedAvatarsView: View {
    let overlap: CGFloat
    let lineWidth: CGFloat
    var shouldStackFromLast = false
    let avatars: [StackedAvatarInfo]
    let avatarSize: Avatars.Size
    let mediaProvider: MediaProviderProtocol?
    
    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(0..<avatars.count, id: \.self) { index in
                LoadableAvatarImage(url: avatars[index].url,
                                    name: avatars[index].name,
                                    // PG_CHANGED
                                    email: avatars[index].email,
                                    contentID: avatars[index].contentID,
                                    avatarSize: avatarSize,
                                    mediaProvider: mediaProvider)
                    .padding(lineWidth)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.compound.bgCanvasDefault, lineWidth: lineWidth)
                    }
                    .zIndex(shouldStackFromLast ? Double(index) : Double(avatars.count - index))
            }
        }
    }
}

struct StackedAvatarsView_Previews: PreviewProvider, TestablePreview {
    static let avatars: [StackedAvatarInfo] = [
        .init(url: nil, name: "Alice", email: "alice@matrix.org", contentID: "@alice:matrix.org"),
        .init(url: nil, name: "Bob", email: "bob@matrix.org", contentID: "@bob:matrix.org"),
        .init(url: nil, name: "Charlie", email: "charlie@matrix.org", contentID: "@charlie:matrix.org"),
        .init(url: nil, name: "Dan", email: "dan@matrix.org", contentID: "@dan:matrix.org")
    ]

    static var previews: some View {
        VStack(spacing: 10) {
            StackedAvatarsView(overlap: 16,
                               lineWidth: 2,
                               avatars: avatars,
                               avatarSize: .user(on: .knockingUsersBannerStack),
                               mediaProvider: MediaProviderMock())
            StackedAvatarsView(overlap: 16,
                               lineWidth: 2,
                               shouldStackFromLast: true,
                               avatars: avatars,
                               avatarSize: .user(on: .knockingUsersBannerStack),
                               mediaProvider: MediaProviderMock())
        }
    }
}
