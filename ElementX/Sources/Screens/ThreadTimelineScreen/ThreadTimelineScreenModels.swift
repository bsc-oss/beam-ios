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

enum ThreadTimelineScreenViewModelAction {
    case displayMessageForwarding(MessageForwardingItem)
}

struct ThreadTimelineScreenViewState: BindableState {
    // PG_CHANGED - displays email in DM room header view subtitle
    var roomSubtitle: String
    var roomAvatar: RoomAvatar
    var canSendMessage = true
    var dmRecipientVerificationState: UserIdentityVerificationState?
    var roomHistorySharingState: RoomHistorySharingState?
    
    var bindings = ThreadTimelineScreenViewStateBindings()
}

struct ThreadTimelineScreenViewStateBindings {
    /// The view model used to present a QuickLook media preview.
    var mediaPreviewViewModel: TimelineMediaPreviewViewModel?
}

enum ThreadTimelineScreenViewAction { }
