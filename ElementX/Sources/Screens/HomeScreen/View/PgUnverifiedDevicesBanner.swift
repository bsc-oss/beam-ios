//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

// PG_CHANGED - TEMPORARY: unverified devices warning, to be removed once MSC4153 (exclude insecure devices) is adopted.

/// Warns that the account has devices which were never verified, and links to the account provider page where they can
/// be reviewed and signed out. A device can't be verified from there: verification has to be started on the device itself.
///
/// It can't be dismissed: it stays until every device is verified or signed out, because until then the user can't send
/// messages or start calls.
struct PgUnverifiedDevicesBanner: View {
    let deviceCount: Int
    /// Nil when the homeserver doesn't expose a device management page, which hides the action.
    let onManageDevices: (() -> Void)?
    
    private var type: PgAnnouncementType {
        if let onManageDevices {
            .actionable(actionTitle: L10n.pgScreenRoomListUnverifiedDevicesAction, action: onManageDevices, onDismiss: nil, isCritical: true)
        } else {
            .informative(isCritical: true)
        }
    }
    
    var body: some View {
        PgAnnouncement(title: L10n.pgScreenRoomListUnverifiedDevicesTitle(deviceCount),
                       message: L10n.pgScreenRoomListUnverifiedDevicesMessage(deviceCount),
                       type: type)
            .padding(.horizontal, 16)
    }
}

struct PgUnverifiedDevicesBanner_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(spacing: 16) {
            PgUnverifiedDevicesBanner(deviceCount: 2) { }
                .previewDisplayName("Several devices")
            
            PgUnverifiedDevicesBanner(deviceCount: 1) { }
                .previewDisplayName("Single device")
            
            PgUnverifiedDevicesBanner(deviceCount: 1, onManageDevices: nil)
                .previewDisplayName("Without device management page")
        }
        .padding(.vertical)
    }
}
