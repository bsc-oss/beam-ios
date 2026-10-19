//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-10-05

import AVFoundation
import Foundation
import UIKit

// sourcery: AutoMockable
protocol AppMediatorProtocol {
    var windowManager: WindowManagerProtocol { get }
    var networkMonitor: NetworkMonitorProtocol { get }
    
    var appState: UIApplication.State { get }
    
    func open(_ url: URL)
    
    func openAppSettings()
    
    func setIdleTimerDisabled(_ disabled: Bool)
    
    func requestAuthorizationIfNeeded() async -> Bool
    
    // PG_CHANGED - lets calls tell whether a refused microphone or camera is blocked by the system
    func mediaCaptureAuthorizationStatus(for mediaType: AVMediaType) -> AVAuthorizationStatus
}

extension UIApplication.State: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}

extension UIUserInterfaceActiveAppearance: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .unspecified:
            return "unspecified"
        @unknown default:
            return "unknown"
        }
    }
}
