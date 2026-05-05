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

import Compound
import Foundation
import SwiftUI

struct CallNotificationRoomTimelineView: View {
    @Environment(\.timelineContext) private var context
    
    let timelineItem: CallNotificationRoomTimelineItem
    
    var body: some View {
        HStack(spacing: 12) {
            LoadableAvatarImage(url: timelineItem.sender.avatarURL,
                                // PG_CHANGED
                                name: timelineItem.sender.primaryInfo,
                                email: timelineItem.sender.email,
                                contentID: timelineItem.sender.id,
                                avatarSize: .user(on: .timeline),
                                mediaProvider: context?.mediaProvider)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 0) {
                // PG_CHANGED
                Text(timelineItem.sender.disambiguatedDisplayName ?? timelineItem.sender.emailOrId)
                    .font(.compound.bodyLGSemibold)
                    .foregroundColor(.compound.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Label(title: { Text(L10n.commonCallStarted) },
                      // PG_CHANGED - voiceCallSold instead of videoCallSolid.
                      icon: { CompoundIcon(\.voiceCallSolid, size: .medium, relativeTo: .compound.bodyMD) })
                    .font(.compound.bodyMD)
                    .foregroundColor(.compound.textSecondary)
                    .labelStyle(.custom(spacing: 4))
            }
            
            Spacer()
            
            Text(timelineItem.timestamp.formattedTime())
                .font(.compound.bodyXS)
                .foregroundColor(.compound.textSecondary)
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(.compound.borderInteractiveSecondary, lineWidth: 1))
        .padding(16)
    }
}

struct CallNotificationRoomTimelineView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = TimelineViewModel.mock
    
    static var previews: some View {
        body.environmentObject(viewModel.context)
        // PG_CHANGED
        emailOnlyBody.environmentObject(viewModel.context).previewDisplayName("Email only")
    }
    
    static var body: some View {
        CallNotificationRoomTimelineView(timelineItem: .init(id: .randomEvent,
                                                             timestamp: .mock,
                                                             isEditable: false,
                                                             canBeRepliedTo: false,
                                                             sender: .init(id: "Bob")))
    }
    
    // PG_CHANGED
    static var emailOnlyBody: some View {
        CallNotificationRoomTimelineView(timelineItem: .init(id: .randomEvent,
                                                             timestamp: .mock,
                                                             isEditable: false,
                                                             canBeRepliedTo: false,
                                                             sender: .init(id: "@test:matrix.org", displayName: nil, email: "test@matrix.org")))
    }
}
