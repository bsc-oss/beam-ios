//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct PgEmailInputScreenCoordinatorParameters {
    let authenticationService: AuthenticationServiceProtocol
    let pgEmailValidationService: PgEmailValidationServiceProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
    let appSettings: AppSettings
}

enum PgEmailInputScreenCoordinatorAction {
    case continueWithOIDC(data: OIDCAuthorizationDataProxy, window: UIWindow)
}

final class PgEmailInputScreenCoordinator: CoordinatorProtocol {
    private var viewModel: PgEmailInputScreenViewModelProtocol
    private let actionsSubject: PassthroughSubject<PgEmailInputScreenCoordinatorAction, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    
    var actions: AnyPublisher<PgEmailInputScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(parameters: PgEmailInputScreenCoordinatorParameters) {
        viewModel = PgEmailInputScreenViewModel(authenticationService: parameters.authenticationService,
                                                pgEmailValidationService: parameters.pgEmailValidationService,
                                                userIndicatorController: parameters.userIndicatorController,
                                                appSettings: parameters.appSettings)
    }
    
    func start() {
        viewModel.actions.sink { [weak self] action in
            guard let self else { return }
            
            switch action {
            case .continueWithOIDC(let oidcData, let window):
                actionsSubject.send(.continueWithOIDC(data: oidcData, window: window))
            }
        }
        .store(in: &cancellables)
    }
        
    func toPresentable() -> AnyView {
        AnyView(PgEmailInputScreen(context: viewModel.context))
    }
    
    /// PG_CHANGED - clears pending OIDC state after the flow completes or is cancelled.
    func clearPendingOIDC() {
        viewModel.clearPendingOIDC()
    }
}
