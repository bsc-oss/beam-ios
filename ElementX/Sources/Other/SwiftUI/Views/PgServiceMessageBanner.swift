//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// Banner that surfaces a remote service message (notice) to the user as a ``PgAnnouncement``.
///
/// It is dismissible only when `message.allowDismiss` is true and an `onDismiss` closure is provided
/// (the login screen passes `nil` to make the banner non-dismissible).
struct PgServiceMessageBanner: View {
    let message: PgServiceMessageDisplay
    /// Optional dismiss handler. When `nil`, the banner is rendered without a close button.
    let onDismiss: (() -> Void)?
    
    private var type: PgAnnouncementType {
        if let onDismiss, message.allowDismiss {
            .actionable(actionTitle: L10n.actionOk, action: onDismiss, onDismiss: onDismiss, isCritical: message.isCritical)
        } else {
            .informative(isCritical: message.isCritical)
        }
    }
    
    var body: some View {
        PgAnnouncement(title: message.title, message: message.body, type: type)
            .padding(.horizontal, 16)
    }
}

struct PgServiceMessageBanner_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(spacing: 16) {
            PgServiceMessageBanner(message: .init(id: 1,
                                                  isCritical: false,
                                                  allowDismiss: true,
                                                  title: "Scheduled maintenance",
                                                  body: "Beam will be temporarily unavailable on Sunday between 02:00 and 04:00."),
                                   onDismiss: { })
                .previewDisplayName("Informative – dismissible")
            
            PgServiceMessageBanner(message: .init(id: 2,
                                                  isCritical: true,
                                                  allowDismiss: false,
                                                  title: "Service disruption",
                                                  body: "We are currently investigating an issue affecting message delivery."),
                                   onDismiss: nil)
                .previewDisplayName("Critical – non-dismissible")
            
            PgServiceMessageBanner(message: .init(id: 3,
                                                  isCritical: false,
                                                  allowDismiss: true,
                                                  title: nil,
                                                  body: "A short informative notice without a title."),
                                   onDismiss: { })
                .previewDisplayName("Informative – body only")
        }
        .padding(.vertical)
    }
}
