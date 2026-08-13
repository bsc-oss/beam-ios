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

import SwiftUI

enum AuthenticationStartScreenViewModelAction: Equatable {
    case loginWithQR
    case login
    case register
    
    case loginDirectlyWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    case loginDirectlyWithPassword(loginHint: String?)
    
    case reportProblem
    case developerOptions
}

struct AuthenticationStartScreenViewState: BindableState {
    /// The presentation anchor used for OAuth authentication.
    var window: UIWindow?
    
    let serverName: String?
    let showCreateAccountButton: Bool
    let showQRCodeLoginButton: Bool
    
    enum ClassicAppMode { case welcomeBack(ClassicAppAccount), otherOptions(ClassicAppAccount) }
    var classicAppMode: ClassicAppMode?
    
    let hideBrandChrome: Bool

    let showDeveloperOptions: Bool // PG_CHANGED - gate the dev options button by developerOptionsEnabled instead of build configuration

    var serviceMessage: PgServiceMessageDisplay? // PG_CHANGED
    
    var bindings = AuthenticationStartScreenViewStateBindings()
    
    // PG_CHANGED - removes loginButtonTitle computed property.
}

struct AuthenticationStartScreenViewStateBindings {
    var alertInfo: AlertInfo<AuthenticationStartScreenAlertType>?
    var showClassicAppBackupInstructions = false
}

enum AuthenticationStartScreenAlertType {
    case genericError
}

enum AuthenticationStartScreenViewAction {
    /// Updates the window used as the OAuth presentation anchor.
    case updateWindow(UIWindow)
    case developerOptions
    case reportProblem
    
    case loginWithQR
    case login
    case register
    
    case continueWithClassic(ClassicAppAccount)
    case otherOptions(ClassicAppAccount)
    case closeOtherOptions(ClassicAppAccount)
    case openClassicApp
}
