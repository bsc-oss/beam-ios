//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
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
    case continueWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
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
            case .continueWithOAuth(let oAuthData, let window):
                actionsSubject.send(.continueWithOAuth(data: oAuthData, window: window))
            }
        }
        .store(in: &cancellables)
    }
        
    func toPresentable() -> AnyView {
        AnyView(PgEmailInputScreen(context: viewModel.context))
    }
    
    // PG_CHANGED - clears pending OAuth state after the flow completes or is cancelled.
    func clearPendingOAuth() {
        viewModel.clearPendingOAuth()
    }
}
