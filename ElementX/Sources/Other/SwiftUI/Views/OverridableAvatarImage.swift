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
import SwiftUI

struct OverridableAvatarImage: View {
    let overrideURL: URL?
    let url: URL?
    let name: String?
    let contentID: String
    let shape: LoadableAvatarImage.Shape
    let avatarSize: Avatars.Size
    let mediaProvider: MediaProviderProtocol?
    
    var body: some View {
        if let overrideURL {
            AsyncImage(url: overrideURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
            }
            .scaledFrame(size: avatarSize.value)
            .avatarShape(shape, size: avatarSize.value)
        } else {
            LoadableAvatarImage(url: url,
                                name: name,
                                // PG_CHANGED
                                email: nil,
                                contentID: contentID,
                                shape: shape,
                                avatarSize: avatarSize,
                                mediaProvider: mediaProvider)
        }
    }
}
