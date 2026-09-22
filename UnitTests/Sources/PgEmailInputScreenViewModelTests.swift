//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDKMocks
import XCTest

@MainActor
final class PgEmailInputScreenViewModelTests: XCTestCase {
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
    
    override func setUp() {
        AppSettings.resetAllSettings()
        appSettings = AppSettings()
        userIndicatorController = UserIndicatorControllerMock()
    }
    
    override func tearDown() {
        AppSettings.resetAllSettings()
    }
    
    // MARK: - Tests
    
    func testConfirmWithInvalidEmailFormatShowsFooterError() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "matrix.org")))
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "not-an-email"
        
        context.send(viewAction: .confirm)
        
        // Allow async task to run
        try await Task.sleep(for: .milliseconds(50))
        
        XCTAssertEqual(viewModel.state.footerErrorMessage, L10n.pgEmailInputScreenEmailInputInvalidEmailFormatFooterMessage)
        XCTAssertNil(viewModel.state.bindings.alertInfo)
        XCTAssertEqual(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount, 0)
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount, 0)
    }
    
    func testClearFooterError() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "matrix.org")))
        context.send(viewAction: .updateWindow(UIWindow()))
        viewModel.state.bindings.email = "invalid"
        context.send(viewAction: .confirm)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNotNil(viewModel.state.footerErrorMessage)
        
        context.send(viewAction: .clearFooterError)
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertNil(viewModel.state.footerErrorMessage)
    }
    
    func testUnknownEmailDomainError() async throws {
        setupViewModel(emailValidationResult: .failure(.unknownEmailDomainError))
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "user@example.com"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0 != nil }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        XCTAssertEqual(viewModel.state.bindings.alertInfo?.id, .unknownEmailDomainError)
        XCTAssertEqual(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount, 0)
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount, 0)
    }
    
    func testSuccessfulOIDCFlow() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(viewModel.actions) {
            if case .continueWithOAuth = $0 { return true }
            return false
        }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        XCTAssertEqual(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount, 1)
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount, 1)
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesReceivedArguments?.loginHint, "firstname.lastname@domain.be")
    }
    
    func testLoginNotSupportedAlert() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")),
                       supportsOAuth: false)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0 != nil }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        XCTAssertEqual(viewModel.state.bindings.alertInfo?.id, .login)
        XCTAssertEqual(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount, 1)
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount, 0)
    }
    
    func testMissingWindowShowsUnknownErrorOnOIDCPath() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0?.id == .unknownError }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        XCTAssertEqual(viewModel.state.bindings.alertInfo?.id, .unknownError)
        XCTAssertEqual(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount, 1)
        // Should not attempt to fetch OIDC URL without a window.
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount, 0)
    }
    
    // MARK: - isLoading tests
    
    func testIsLoadingSetDuringConfirm() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        XCTAssertFalse(viewModel.state.isLoading)
        
        let deferred = deferFulfillment(viewModel.actions) {
            if case .continueWithOAuth = $0 { return true }
            return false
        }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        // isLoading stays true after OIDC action is sent (until clearPendingOAuth is called)
        XCTAssertTrue(viewModel.state.isLoading)
    }
    
    func testIsLoadingPreventsMultipleRequests() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(viewModel.actions) {
            if case .continueWithOAuth = $0 { return true }
            return false
        }
        
        // Send confirm twice rapidly
        context.send(viewAction: .confirm)
        context.send(viewAction: .confirm)
        
        try await deferred.fulfill()
        
        // Only one request should have been made
        XCTAssertEqual(emailValidationService.validateEmailEmailCallsCount, 1)
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount, 1)
    }
    
    func testClearPendingOIDCResetsIsLoading() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "firstname.lastname@domain.be"
        
        let deferred = deferFulfillment(viewModel.actions) {
            if case .continueWithOAuth = $0 { return true }
            return false
        }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        XCTAssertTrue(viewModel.state.isLoading)
        
        // Simulate coordinator calling clearPendingOAuth after OIDC cancel
        viewModel.clearPendingOAuth()
        
        XCTAssertFalse(viewModel.state.isLoading)
    }
    
    func testIsLoadingResetOnError() async throws {
        setupViewModel(emailValidationResult: .failure(.unknownEmailDomainError))
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = "user@example.com"
        
        let deferred = deferFulfillment(context.observe(\.alertInfo)) { $0 != nil }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        // isLoading should be reset on error so user can retry
        XCTAssertFalse(viewModel.state.isLoading)
    }
    
    func testConfirmTrimsLeadingSpace() async throws {
        try await assertEmailIsTrimmed(input: " firstname.lastname@domain.be")
    }
    
    func testConfirmTrimsLeadingSpaces() async throws {
        try await assertEmailIsTrimmed(input: "   firstname.lastname@domain.be")
    }
    
    func testConfirmTrimsTrailingSpace() async throws {
        try await assertEmailIsTrimmed(input: "firstname.lastname@domain.be ")
    }
    
    func testConfirmTrimsTrailingSpaces() async throws {
        try await assertEmailIsTrimmed(input: "firstname.lastname@domain.be   ")
    }
    
    func testConfirmTrimsLeadingAndTrailingSpaces() async throws {
        try await assertEmailIsTrimmed(input: "  firstname.lastname@domain.be  ")
    }
    
    func testConfirmTrimsLeadingTab() async throws {
        try await assertEmailIsTrimmed(input: "\tfirstname.lastname@domain.be")
    }
    
    func testConfirmTrimsTrailingTab() async throws {
        try await assertEmailIsTrimmed(input: "firstname.lastname@domain.be\t")
    }
    
    func testConfirmTrimsLeadingAndTrailingTabs() async throws {
        try await assertEmailIsTrimmed(input: "\tfirstname.lastname@domain.be\t")
    }
    
    func testConfirmTrimsMixedWhitespace() async throws {
        try await assertEmailIsTrimmed(input: " \t firstname.lastname@domain.be \t ")
    }
    
    func testIsLoadingResetOnInvalidEmail() async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "matrix.org")))
        
        viewModel.state.bindings.email = "not-an-email"
        
        context.send(viewAction: .confirm)
        try await Task.sleep(for: .milliseconds(50))
        
        // isLoading should be reset when email validation fails locally
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNotNil(viewModel.state.footerErrorMessage)
    }
    
    // MARK: - Helpers
    
    /// Asserts that the given email input is trimmed before being sent to the validation service and OIDC login hint.
    private func assertEmailIsTrimmed(input: String, file: StaticString = #file, line: UInt = #line) async throws {
        setupViewModel(emailValidationResult: .success(.init(url: "domain.be")), supportsOAuth: true)
        context.send(viewAction: .updateWindow(UIWindow()))
        
        viewModel.state.bindings.email = input
        
        let deferred = deferFulfillment(viewModel.actions) {
            if case .continueWithOAuth = $0 { return true }
            return false
        }
        context.send(viewAction: .confirm)
        try await deferred.fulfill()
        
        let expected = "firstname.lastname@domain.be"
        XCTAssertEqual(emailValidationService.validateEmailEmailReceivedEmail, expected, "Validation service received untrimmed email", file: file, line: line)
        XCTAssertEqual(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesReceivedArguments?.loginHint, expected, "OIDC login hint received untrimmed email", file: file, line: line)
    }
    
    private func setupViewModel(emailValidationResult: Result<PgEmailValidationResponse, PgEmailValidationError>,
                                supportsOAuth: Bool = true,
                                supportsOAuthCreatePrompt: Bool = true) {
        client = ClientSDKMock(configuration: .init(oAuthLoginURL: supportsOAuth ? "https://account.domain.be/authorize" : nil,
                                                    supportsOAuthCreatePrompt: supportsOAuthCreatePrompt,
                                                    supportsPasswordLogin: false))
        let configuration = AuthenticationClientFactoryMock.Configuration(homeserverClients: ["domain.be": client])
        clientFactory = AuthenticationClientFactoryMock(configuration: configuration)
        
        service = AuthenticationService(userSessionStore: UserSessionStoreMock(configuration: .init()),
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
        if case .continueWithOAuth = self { return true }
        return false
    }
}
