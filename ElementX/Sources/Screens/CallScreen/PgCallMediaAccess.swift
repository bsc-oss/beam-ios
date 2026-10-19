//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Foundation

/// Points to the system settings when pg-call reports a refused microphone or camera request
/// (`controls.onMediaAccessRefused`).
///
/// WebKit asks for the system permission itself and, once it is denied, rejects the request
/// without involving the app, so only pg-call can tell that a request was refused.
/// iOS never asks again once a permission is denied, so every refusal points to the settings,
/// including the one answering the system prompt: unlike Android, that refusal is already final.
struct PgCallMediaAccess {
    private let appMediator: AppMediatorProtocol
    
    init(appMediator: AppMediatorProtocol) {
        self.appMediator = appMediator
    }
    
    /// The media of a refused request that the user must allow in the settings.
    /// - Parameter requestedKinds: The devices the refused request asked for, as named by pg-call.
    func mediaTypesToAllowInSettings(requestedKinds: [String]) -> [AVMediaType] {
        requestedKinds.compactMap(Self.mediaType(fromKind:)).filter { mediaType in
            // Any other status means WebKit refused on its own (e.g. a denial it remembers), which the settings can't fix.
            switch appMediator.mediaCaptureAuthorizationStatus(for: mediaType) {
            case .denied, .restricted: true
            default: false
            }
        }
    }
    
    /// The alert offering to open the settings to allow these media.
    func settingsAlert(for mediaTypes: [AVMediaType]) -> AlertInfo<UUID> {
        // Like Android, name the microphone first when both are blocked. The iOS texts add that
        // the app restarts when the permission changes, which ends the call.
        let message = mediaTypes.contains(.audio) ? L10n.dialogPermissionMicrophone : L10n.dialogPermissionCamera
        return AlertInfo(id: UUID(),
                         title: L10n.commonPermission,
                         message: message,
                         primaryButton: .init(title: L10n.actionOpenSettings) { [appMediator] in appMediator.openAppSettings() },
                         secondaryButton: .init(title: L10n.actionNotNow, role: .cancel, action: nil))
    }
    
    private static func mediaType(fromKind kind: String) -> AVMediaType? {
        switch kind {
        case "microphone": .audio
        case "camera": .video
        default: nil
        }
    }
}
