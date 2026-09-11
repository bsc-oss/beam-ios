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

import Combine
import SwiftUI

typealias AuthenticationStartScreenViewModelType = StateStoreViewModelV2<AuthenticationStartScreenViewState, AuthenticationStartScreenViewAction>

class AuthenticationStartScreenViewModel: AuthenticationStartScreenViewModelType, AuthenticationStartScreenViewModelProtocol {
    private let authenticationService: AuthenticationServiceProtocol
    private let provisioningParameters: AccountProvisioningParameters?
    private let pgServiceMessageService: PgServiceMessageServiceProtocol // PG_CHANGED
    private let appMediator: AppMediatorProtocol
    private let appSettings: AppSettings
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let canReportProblem: Bool
    
    private var actionsSubject: PassthroughSubject<AuthenticationStartScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<AuthenticationStartScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(authenticationService: AuthenticationServiceProtocol,
         provisioningParameters: AccountProvisioningParameters?,
         pgServiceMessageService: PgServiceMessageServiceProtocol, // PG_CHANGED
         isBugReportServiceEnabled: Bool,
         appMediator: AppMediatorProtocol,
         appSettings: AppSettings,
         mediaProvider: MediaProviderProtocol?,
         notificationCenter: NotificationCenter = .default,
         userIndicatorController: UserIndicatorControllerProtocol) {
        self.authenticationService = authenticationService
        self.provisioningParameters = provisioningParameters
        self.pgServiceMessageService = pgServiceMessageService // PG_CHANGED
        self.appMediator = appMediator
        self.appSettings = appSettings
        self.userIndicatorController = userIndicatorController
        canReportProblem = isBugReportServiceEnabled
        
        // PG_CHANGED - disables logging in with QR code
        let isQRCodeScanningSupported = false
        // Classic-app account lookup kept from upstream; resolves to nil at runtime because the classic-app feature is disabled (no Info.plist config)
        let classicAppAccountProvider = authenticationService.classicAppAccount?.serverName
        let isClassicAppAccountAllowed = classicAppAccountProvider.map { appSettings.accountProviders.contains($0) } ?? false
        let showDeveloperOptions = appSettings.developerOptionsEnabled // PG_CHANGED

        let initialViewState = if !appSettings.allowOtherAccountProviders {
            // We don't show the create account button when custom providers are disallowed.
            // The assumption here being that if you're running a custom app, your users will already be created.
            AuthenticationStartScreenViewState(serverName: appSettings.accountProviders.count == 1 ? appSettings.accountProviders[0] : nil,
                                               showCreateAccountButton: false,
                                               showQRCodeLoginButton: isQRCodeScanningSupported,
                                               classicAppMode: isClassicAppAccountAllowed ? authenticationService.classicAppAccount.map { .welcomeBack($0) } : nil,
                                               hideBrandChrome: appSettings.hideBrandChrome,
                                               showDeveloperOptions: showDeveloperOptions, // PG_CHANGED
                                               serviceMessage: pgServiceMessageService.currentMessagePublisher.value) // PG_CHANGED
        } else if let provisioningParameters {
            // We only show the "Sign in to …" button when using a provisioning link.
            AuthenticationStartScreenViewState(serverName: provisioningParameters.accountProvider,
                                               showCreateAccountButton: false,
                                               showQRCodeLoginButton: false,
                                               classicAppMode: nil,
                                               hideBrandChrome: appSettings.hideBrandChrome,
                                               showDeveloperOptions: showDeveloperOptions, // PG_CHANGED
                                               serviceMessage: pgServiceMessageService.currentMessagePublisher.value) // PG_CHANGED
        } else {
            // The default configuration.
            AuthenticationStartScreenViewState(serverName: nil,
                                               showCreateAccountButton: appSettings.showCreateAccountButton,
                                               showQRCodeLoginButton: isQRCodeScanningSupported,
                                               classicAppMode: authenticationService.classicAppAccount.map { .welcomeBack($0) },
                                               hideBrandChrome: appSettings.hideBrandChrome,
                                               showDeveloperOptions: showDeveloperOptions, // PG_CHANGED
                                               serviceMessage: pgServiceMessageService.currentMessagePublisher.value) // PG_CHANGED
        }
        
        super.init(initialViewState: initialViewState, mediaProvider: mediaProvider)
        
        // PG_CHANGED - service message updates
        pgServiceMessageService.currentMessagePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.serviceMessage, on: self)
            .store(in: &cancellables)
        
        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.reloadClassicAppAccount()
            }
            .store(in: &cancellables)
    }
    
    override func process(viewAction: AuthenticationStartScreenViewAction) {
        switch viewAction {
        case .updateWindow(let window):
            guard state.window != window else { return }
            state.window = window
        case .reportProblem:
            if canReportProblem {
                actionsSubject.send(.reportProblem)
            }
        case .developerOptions:
            actionsSubject.send(.developerOptions)
        
        case .loginWithQR:
            actionsSubject.send(.loginWithQR)
        case .login:
            Task { await login() }
        case .register:
            actionsSubject.send(.register)
        
        case .continueWithClassic(let account):
            Task { await login(classicAppAccount: account) }
        case .otherOptions(let account):
            state.classicAppMode = .otherOptions(account)
        case .closeOtherOptions(let account):
            state.classicAppMode = .welcomeBack(account)
        case .openClassicApp:
            guard let classicAppDeepLinkURL = InfoPlistReader.main.classicAppDeepLinkURL else { return }
            appMediator.open(classicAppDeepLinkURL)
        }
    }
    
    // MARK: - Private
    
    private func login(classicAppAccount: ClassicAppAccount? = nil) async {
        if let classicAppAccount {
            if classicAppAccount.state.availableSecrets == .requiresBackup {
                state.bindings.showClassicAppBackupInstructions = true
            } else {
                await configureAccountProvider(classicAppAccount.serverName,
                                               loginHint: "mxid:\(classicAppAccount.userID)",
                                               fallbackHomeserverURL: classicAppAccount.homeserverURL)
            }
        } else if let serverName = state.serverName {
            await configureAccountProvider(serverName, loginHint: provisioningParameters?.loginHint)
        } else {
            actionsSubject.send(.login) // No need to configure anything here, continue the flow.
        }
    }
    
    private func configureAccountProvider(_ accountProvider: String, loginHint: String? = nil, fallbackHomeserverURL: URL? = nil) async {
        startLoading()
        defer { stopLoading() }
        
        if case .failure = await authenticationService.configure(for: accountProvider, flow: .login) {
            // Try the fallback URL before showing an error.
            if let fallbackHomeserverURL,
               case .success = await authenticationService.configure(for: fallbackHomeserverURL.absoluteString, flow: .login) {
                // Fallback succeeded, continue with the flow.
            } else {
                // As the server was provisioned, we don't worry about the specifics and show a generic error to the user.
                // Element Classic accounts aren't shown for unsupported servers either, so nothing to do here.
                displayError()
                return
            }
        }
        
        guard authenticationService.homeserver.value.loginMode.supportsOAuthFlow else {
            actionsSubject.send(.loginDirectlyWithPassword(loginHint: loginHint))
            return
        }
        
        guard let window = state.window else {
            displayError()
            return
        }
        
        switch await authenticationService.urlForOAuthLogin(loginHint: loginHint) {
        case .success(let oAuthData):
            actionsSubject.send(.loginDirectlyWithOAuth(data: oAuthData, window: window))
        case .failure:
            displayError()
        }
    }
    
    @CancellableTask private var reloadClassicAppSecretsTask: Task<Void, Never>?
    private func reloadClassicAppAccount() {
        guard case let .welcomeBack(classicAppAccount) = state.classicAppMode else { return }
        
        reloadClassicAppSecretsTask = Task { [weak self] in
            await self?.authenticationService.refreshClassicAppAccountState()
            
            guard !Task.isCancelled else { return }
            
            if let availableSecrets = classicAppAccount.state.availableSecrets, availableSecrets != .requiresBackup {
                await MainActor.run { self?.state.bindings.showClassicAppBackupInstructions = false }
            }
        }
    }
    
    // MARK: - User Indicators
    
    private let loadingIndicatorID = "\(AuthenticationStartScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: loadingIndicatorID,
                                                              type: .modal,
                                                              title: L10n.commonLoading,
                                                              persistent: true))
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(loadingIndicatorID)
    }
    
    private func displayError() {
        state.bindings.alertInfo = AlertInfo(id: .genericError)
    }
}
