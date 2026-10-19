//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDKMocks
import Testing
import UIKit

@MainActor
final class PgEmailInputScreenViewModelTests {
    var clientFactory: AuthenticationClientFactoryMock!
    var client: ClientSDKMock!
    var service: AuthenticationServiceProtocol!
    var appSettings: AppSettings!
    var emailValidationService: PgEmailValidationServiceMock! // Use generated mock
    var userIndicatorController: UserIndicatorControllerMock!
    
    var viewModel: PgEmailInputScreenViewModel!
    var context: PgEmailInputScreenViewModel.Context {
        viewModel.context
    }
    
    init() {
        appSettings = AppSettings.volatile()
        userIndicatorController = UserIndicatorControllerMock()
    }
    
    // MARK: - Tests
    
    @Test
    func confirmWithInvalidEmailFormatShowsFooterError() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "matrix.org")))
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "not-an-email"
        
        context.send(viewAction: .confirm)
        
        // Allow async task to run
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(viewModel.state.footerErrorMessage == L10n.pgEmailInputScreenEmailInputInvalidEmailFormatFooterMessage)
        #expect(viewModel.state.bindings.alertInfo == nil)
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 0)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
    }
    
    @Test
    func clearFooterError() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "matrix.org")))
        context.send(viewAction: .updateWindow(UIWindow()))
        viewModel.state.bindings.email = "invalid"
        context.send(viewAction: .confirm)
        try await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.state.footerErrorMessage != nil)
        
        context.send(viewAction: .clearFooterError)
        try await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.state.footerErrorMessage == nil)
    }
    
    @Test
    func unknownEmailDomainError() async throws {
        setupViewModel(emailValidationResult: .failure(.unknownEmailDomainError))
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "user@example.com"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0 != nil }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        #expect(viewModel.state.bindings.alertInfo?.id == .unknownEmailDomainError)
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 0)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
    }
    
    @Test
    func successfulOIDCFlow() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(viewModel.actions) { $0.isContinueWithOAuth }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 1)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesReceivedArguments?.loginHint == "firstname.lastname@domain.be")
    }
    
    @Test
    func loginNotSupportedAlert() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")),
                       supportsOAuth: false)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0 != nil }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        #expect(viewModel.state.bindings.alertInfo?.id == .login)
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
    }
    
    @Test
    func missingWindowShowsUnknownErrorOnOIDCPath() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0?.id == .unknownError }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        #expect(viewModel.state.bindings.alertInfo?.id == .unknownError)
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        // Should not attempt to fetch OIDC URL without a window.
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
    }
    
    // MARK: - isLoading tests
    
    @Test
    func isLoadingSetDuringConfirm() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        #expect(!viewModel.state.isLoading)
        
        let deferred = deferFulfillment(viewModel.actions) { $0.isContinueWithOAuth }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        // isLoading stays true after OIDC action is sent (until clearPendingOAuth is called)
        #expect(viewModel.state.isLoading)
    }
    
    @Test
    func isLoadingPreventsMultipleRequests() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(viewModel.actions) { $0.isContinueWithOAuth }
        
        // Send confirm twice rapidly
        context.send(viewAction: .confirm)
        context.send(viewAction: .confirm)
        
        try await deferred.fulfill()
        
        // Only one request should have been made
        #expect(emailValidationService.validateEmailEmailCallsCount == 1)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 1)
    }
    
    @Test
    func clearPendingOIDCResetsIsLoading() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(viewModel.actions) { $0.isContinueWithOAuth }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        #expect(viewModel.state.isLoading)
        
        // Simulate coordinator calling clearPendingOAuth after OIDC cancel
        viewModel.clearPendingOAuth()
        
        #expect(!viewModel.state.isLoading)
    }
    
    @Test
    func isLoadingResetOnError() async throws {
        setupViewModel(emailValidationResult: .failure(.unknownEmailDomainError))
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "user@example.com"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0 != nil }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        // isLoading should be reset on error so user can retry
        #expect(!viewModel.state.isLoading)
    }
    
    @Test
    func confirmTrimsLeadingSpace() async throws {
        try await assertEmailIsTrimmed(input: " firstname.lastname@domain.be")
    }
    
    @Test
    func confirmTrimsLeadingSpaces() async throws {
        try await assertEmailIsTrimmed(input: "   firstname.lastname@domain.be")
    }
    
    @Test
    func confirmTrimsTrailingSpace() async throws {
        try await assertEmailIsTrimmed(input: "firstname.lastname@domain.be ")
    }
    
    @Test
    func confirmTrimsTrailingSpaces() async throws {
        try await assertEmailIsTrimmed(input: "firstname.lastname@domain.be   ")
    }
    
    @Test
    func confirmTrimsLeadingAndTrailingSpaces() async throws {
        try await assertEmailIsTrimmed(input: "  firstname.lastname@domain.be  ")
    }
    
    @Test
    func confirmTrimsLeadingTab() async throws {
        try await assertEmailIsTrimmed(input: "\tfirstname.lastname@domain.be")
    }
    
    @Test
    func confirmTrimsTrailingTab() async throws {
        try await assertEmailIsTrimmed(input: "firstname.lastname@domain.be\t")
    }
    
    @Test
    func confirmTrimsLeadingAndTrailingTabs() async throws {
        try await assertEmailIsTrimmed(input: "\tfirstname.lastname@domain.be\t")
    }
    
    @Test
    func confirmTrimsMixedWhitespace() async throws {
        try await assertEmailIsTrimmed(input: " \t firstname.lastname@domain.be \t ")
    }
    
    @Test
    func isLoadingResetOnInvalidEmail() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "matrix.org")))
        
        viewModel.state.bindings.email = "not-an-email"
        
        context.send(viewAction: .confirm)
        try await Task.sleep(for: .milliseconds(50))
        
        // isLoading should be reset when email validation fails locally
        #expect(!viewModel.state.isLoading)
        #expect(viewModel.state.footerErrorMessage != nil)
    }
    
    // MARK: - Helpers
    
    /// Asserts that the given email input is trimmed before being sent to the validation service and OIDC login hint.
    private func assertEmailIsTrimmed(input: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = input
        
        let deferred = deferFulfillment(viewModel.actions) { $0.isContinueWithOAuth }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        let expected = "firstname.lastname@domain.be"
        #expect(emailValidationService.validateEmailEmailReceivedEmail == expected,
                "Validation service received untrimmed email",
                sourceLocation: sourceLocation)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesReceivedArguments?.loginHint == expected,
                "OIDC login hint received untrimmed email",
                sourceLocation: sourceLocation)
    }
    
    private func setupViewModel(emailValidationResult: Result<PgEmailValidationResponse, PgEmailValidationError>,
                                supportsOAuth: Bool = true,
                                supportsOAuthCreatePrompt: Bool = true) {
        client = ClientSDKMock(.init(oAuthLoginURL: supportsOAuth ? "https://account.domain.be/authorize" : nil,
                                     supportsOAuthCreatePrompt: supportsOAuthCreatePrompt,
                                     supportsPasswordLogin: false))
        let configuration = AuthenticationClientFactoryMock.Configuration(homeserverClients: ["domain.be": client])
        clientFactory = AuthenticationClientFactoryMock(configuration)
        
        service = AuthenticationService(userSessionStore: UserSessionStoreMock(.init()),
                                        encryptionKeyProvider: EncryptionKeyProvider(),
                                        classicAppManager: nil, // PG_CHANGED - classic app disabled in this test
                                        clientFactory: clientFactory,
                                        appSettings: appSettings,
                                        appHooks: AppHooks())
        
        emailValidationService = PgEmailValidationServiceMock()
        emailValidationService.validateEmailEmailReturnValue = emailValidationResult
        
        viewModel = PgEmailInputScreenViewModel(authenticationService: service,
                                                pgEmailValidationService: emailValidationService,
                                                userIndicatorController: userIndicatorController,
                                                appSettings: appSettings)
    }
}

// MARK: - Action helpers

private extension PgEmailInputScreenViewModelAction {
    var isContinueWithOAuth: Bool {
        if case .continueWithOAuth = self {
            return true
        }
        return false
    }
}
