//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-10-05

import AVFoundation
import UIKit

extension AppMediatorMock {
    struct Configuration {
        var appState = UIApplication.State.active
        var isCameraAuthorized = true
        var networkMonitor = NetworkMonitorMock(.init())
        // PG_CHANGED
        var mediaCaptureAuthorizationStatus = AVAuthorizationStatus.authorized
    }
    
    convenience init(_ configuration: Configuration) {
        self.init()
        
        appState = configuration.appState
        requestAuthorizationIfNeededReturnValue = configuration.isCameraAuthorized
        networkMonitor = configuration.networkMonitor
        mediaCaptureAuthorizationStatusForReturnValue = configuration.mediaCaptureAuthorizationStatus // PG_CHANGED
        
        let windowManagerMock = WindowManagerMock()
        windowManagerMock.closeAllSecondaryWindowsClosure = { }
        windowManagerMock.closeSecondaryWindowForTypeClosure = { _ in }
        windowManager = windowManagerMock
    }
}
