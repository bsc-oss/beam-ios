//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
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
