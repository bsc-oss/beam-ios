//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine

@MainActor
protocol PgEmailInputScreenViewModelProtocol {
    var actions: AnyPublisher<PgEmailInputScreenViewModelAction, Never> { get }
    var context: PgEmailInputScreenViewModelType.Context { get }
    /// Clears pending OIDC state and re-enables the continue button after OIDC flow completes/cancels.
    func clearPendingOIDC()
}
