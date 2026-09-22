//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias PgEmailInputScreenViewModelType = StateStoreViewModelV2<PgEmailInputScreenViewState, PgEmailInputScreenViewAction>

class PgEmailInputScreenViewModel: PgEmailInputScreenViewModelType, PgEmailInputScreenViewModelProtocol {
    let authenticationService: AuthenticationServiceProtocol
    let pgEmailValidationService: PgEmailValidationServiceProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
    
    private var actionsSubject: PassthroughSubject<PgEmailInputScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<PgEmailInputScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(authenticationService: AuthenticationServiceProtocol,
         pgEmailValidationService: PgEmailValidationServiceProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         appSettings: AppSettings) {
        self.authenticationService = authenticationService
        self.pgEmailValidationService = pgEmailValidationService
        self.userIndicatorController = userIndicatorController
        
        super.init(initialViewState: PgEmailInputScreenViewState(bindings: .init(), acceptableUseURL: appSettings.acceptableUseURL))
    }
    
    override func process(viewAction: PgEmailInputScreenViewAction) {
        switch viewAction {
        case .updateWindow(let window):
            guard state.window != window else { return }
            Task { state.window = window }
        case .confirm:
            Task { await confirmEmail() }
        case .clearFooterError:
            clearFooterError()
        }
    }
    
    // MARK: - Private
    
    private func confirmEmail() async {
        guard !state.isLoading else { return }
        state.isLoading = true
        
        let trimmedEmail = state.bindings.email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedEmail.isLikelyEmail else {
            showFooterMessage(L10n.pgEmailInputScreenEmailInputInvalidEmailFormatFooterMessage)
            state.isLoading = false
            return
        }
        switch await pgEmailValidationService.validateEmail(email: trimmedEmail) {
        case .success(let response):
            // Note: We don't show the spinner until now as it isn't needed if the service is already
            // configured and we're about to use password based login
            startLoading()
            defer { stopLoading() }
            
            switch await authenticationService.configure(for: response.url, flow: .login) {
            case .success:
                await fetchLoginURLIfNeededAndContinue(loginHint: trimmedEmail)
            case .failure(let error):
                state.isLoading = false
                switch error {
                case .invalidServer, .invalidHomeserverAddress:
                    displayError(.homeserverNotFound)
                case .invalidWellKnown(let error):
                    displayError(.invalidWellKnown(error))
                case .slidingSyncNotAvailable:
                    displayError(.slidingSync)
                case .loginNotSupported:
                    displayError(.login)
                case .registrationNotSupported:
                    displayError(.registration)
                default:
                    displayError(.unknownError)
                }
            }
        case .failure(let error):
            state.isLoading = false
            switch error {
            case .unknownEmailDomainError:
                displayError(.unknownEmailDomainError)
                return
            default:
                displayError(.unknownError)
                return
            }
        }
    }
    
    private func fetchLoginURLIfNeededAndContinue(loginHint: String) async {
        guard authenticationService.homeserver.value.loginMode.supportsOAuthFlow else {
            state.isLoading = false
            return
        }
        
        guard let window = state.window else {
            state.isLoading = false
            displayError(.unknownError)
            return
        }
        
        startLoading() // Uses the same ID, so no need to worry if the indicator already exists
        defer { stopLoading() }
        
        switch await authenticationService.urlForOAuthLogin(loginHint: loginHint) {
        case .success(let oAuthData):
            // Keep isLoading = true until OAuth completes; coordinator resets via clearPendingOAuth()
            actionsSubject.send(.continueWithOAuth(data: oAuthData, window: window))
        case .failure:
            state.isLoading = false
            displayError(.unknownError)
        }
    }
    
    private let loadingIndicatorID = "\(PgEmailInputScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
    
    private func displayError(_ type: PgEmailInputScreenAlert) {
        switch type {
        case .homeserverNotFound:
            state.bindings.alertInfo = AlertInfo(id: .homeserverNotFound,
                                                 title: L10n.errorUnknown,
                                                 message: L10n.screenChangeServerErrorInvalidHomeserver)
        case .invalidWellKnown(let error):
            state.bindings.alertInfo = AlertInfo(id: .invalidWellKnown(error),
                                                 title: L10n.commonServerNotSupported,
                                                 message: L10n.screenChangeServerErrorInvalidWellKnown(error))
        case .slidingSync:
            let nonBreakingAppName = InfoPlistReader.main.bundleDisplayName.replacingOccurrences(of: " ", with: "\u{00A0}")
            state.bindings.alertInfo = AlertInfo(id: .slidingSync,
                                                 title: L10n.commonServerNotSupported,
                                                 message: L10n.screenChangeServerErrorNoSlidingSyncMessage(nonBreakingAppName))
        case .login:
            state.bindings.alertInfo = AlertInfo(id: .login,
                                                 title: L10n.commonServerNotSupported,
                                                 message: L10n.screenLoginErrorUnsupportedAuthentication)
        case .registration:
            state.bindings.alertInfo = AlertInfo(id: .registration,
                                                 title: L10n.commonServerNotSupported,
                                                 message: L10n.errorAccountCreationNotPossible)
        case .unknownError:
            state.bindings.alertInfo = AlertInfo(id: .unknownError)
        case .unknownEmailDomainError:
            state.bindings.alertInfo = AlertInfo(id: .unknownEmailDomainError,
                                                 title: L10n.errorUnknown,
                                                 message: L10n.pgEmailInputScreenUnknownEmailDomainErrorMessage)
        }
    }
    
    /// Set a new error message to be shown in the text field footer.
    private func showFooterMessage(_ message: String) {
        withElementAnimation {
            state.footerErrorMessage = message
        }
    }
    
    /// Clear any errors shown in the text field footer.
    private func clearFooterError() {
        guard state.footerErrorMessage != nil else { return }
        withElementAnimation { state.footerErrorMessage = nil }
    }
    
    // MARK: - PgEmailInputScreenViewModelProtocol
    
    func clearPendingOAuth() {
        state.isLoading = false
    }
}
