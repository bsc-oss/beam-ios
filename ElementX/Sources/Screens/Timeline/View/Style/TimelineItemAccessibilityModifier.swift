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

import SwiftUI

private struct TimelineItemAccessibilityModifier: ViewModifier {
    let timelineItem: RoomTimelineItemProtocol
    let action: () -> Void
    
    func body(content: Content) -> some View {
        switch timelineItem {
        case is PollRoomTimelineItem:
            content
                .accessibilityActions {
                    Button(L10n.commonMessageActions) {
                        action()
                    }
                }
        case let timelineItem as EventBasedTimelineItemProtocol:
            content
                .accessibilityRepresentation {
                    VStack(spacing: 8) {
                        // PG_CHANGED
                        Text(timelineItem.sender.primaryInfo)
                        content
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityActions {
                    Button(L10n.commonMessageActions) {
                        action()
                    }
                }
        default:
            content
                .accessibilityElement(children: .combine)
        }
    }
}

extension View {
    func timelineItemAccessibility(_ timelineItem: RoomTimelineItemProtocol, action: @escaping () -> Void) -> some View {
        modifier(TimelineItemAccessibilityModifier(timelineItem: timelineItem, action: action))
    }
}
