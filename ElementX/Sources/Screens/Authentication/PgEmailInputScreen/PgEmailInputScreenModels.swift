//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

enum PgEmailInputScreenViewModelAction {
    /// Continue the flow using the provided OIDC parameters.
    case continueWithOIDC(data: OIDCAuthorizationDataProxy, window: UIWindow)
}

struct PgEmailInputScreenViewState: BindableState {
    /// The presentation anchor used for OIDC authentication.
    var window: UIWindow?
    
    var bindings = PgEmailInputScreenBindings()
    
    // PG_CHANGED
    /// Whether a confirmation request is in progress.
    var isLoading = false
    // PG_CHANGED
    /// An error message to be shown in the text field footer.
    var footerErrorMessage: String?
    // PG_CHANGED
    var isShowingFooterError: Bool { footerErrorMessage != nil }
    var acceptableUseURL: URL
}

struct PgEmailInputScreenBindings {
    /// Information describing the currently displayed alert.
    var alertInfo: AlertInfo<PgEmailInputScreenAlert>?
    var email = ""
}

enum PgEmailInputScreenViewAction {
    /// Updates the window used as the OIDC presentation anchor.
    case updateWindow(UIWindow)
    /// The user would like to continue with the current homeserver.
    case confirm
    // PG_CHANGED
    /// Clear any errors shown in the text field footer.
    case clearFooterError
}

enum PgEmailInputScreenAlert: Hashable {
    /// An alert that informs the user that a server could not be found.
    case homeserverNotFound
    /// An alert that informs the user about a bad well-known file.
    case invalidWellKnown(String)
    /// An alert that allows the user to learn about sliding sync.
    case slidingSync
    /// An alert that informs the user that login isn't supported.
    case login
    /// An alert that informs the user that registration isn't supported.
    case registration
    /// An unknown error has occurred.
    case unknownError
    // PG_CHANGED
    /// An alert that informs the user his email domain is unknown.
    case unknownEmailDomainError
}
