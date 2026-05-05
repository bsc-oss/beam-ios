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

@MainActor
protocol AppCoordinatorProtocol: CoordinatorProtocol {
    var windowManager: SecureWindowManagerProtocol { get }
    
    @discardableResult func handleDeepLink(_ url: URL, isExternalURL: Bool) -> Bool
    
    func handlePotentialPhishingAttempt(url: URL, openURLAction: @escaping (URL) -> Void) -> Bool
    
    // PG_CHANGED: Handle external link confirmation
    func handleExternalLinkConfirmation(url: URL, openURLAction: @escaping (URL) -> Void) -> Bool
    
    func handleUserActivity(_ userActivity: NSUserActivity)
}
