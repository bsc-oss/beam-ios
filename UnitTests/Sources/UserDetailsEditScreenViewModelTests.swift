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
@testable import ElementX
import MatrixRustSDK
import Testing

@MainActor
struct UserDetailsEditScreenViewModelTests {
    private var viewModel: UserDetailsEditScreenViewModel!
    
    private var context: UserDetailsEditScreenViewModelType.Context {
        viewModel.context
    }
    
    init() {
        viewModel = .init(userSession: UserSessionMock(.init()),
                          mediaUploadingPreprocessor: MediaUploadingPreprocessor(appSettings: .volatile()),
                          userIndicatorController: UserIndicatorControllerMock())
    }
    
    @Test
    func cannotSaveOnLanding() {
        #expect(!context.viewState.canSave)
    }
    
    @Test
    func nameDidChange() {
        context.name = "name"
        #expect(context.viewState.nameDidChange)
        #expect(context.viewState.canSave)
    }
    
    @Test
    func emptyNameCannotBeSaved() {
        context.name = ""
        #expect(!context.viewState.canSave)
    }
    
    @Test
    func avatarPickerShowsSheet() {
        context.name = "name"
        #expect(!context.showMediaSheet)
        context.send(viewAction: .presentMediaSource)
        #expect(context.showMediaSheet)
    }
    
    // PG_CHANGED
    @Test
    mutating func save() async throws {
        let clientProxy = ClientProxyMock(.init())
        setupViewModel(clientProxy: clientProxy)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        
        context.name = "name"
        context.send(viewAction: .save)
        
        try await deferred.fulfill()
    }
    
    @Test
    func cancelWithChangesAndDiscard() async throws {
        context.name = "name"
        #expect(context.viewState.canSave)
        #expect(context.alertInfo == nil)
        
        context.send(viewAction: .cancel)
        
        #expect(context.alertInfo != nil)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.alertInfo?.secondaryButton?.action?() // Discard
        try await deferred.fulfill()
    }
    
    // PG_CHANGED
    @Test
    mutating func cancelWithChangesAndSave() async throws {
        let clientProxy = ClientProxyMock(.init())
        setupViewModel(clientProxy: clientProxy)
        
        context.name = "name"
        #expect(context.viewState.canSave)
        #expect(context.alertInfo == nil)
        
        context.send(viewAction: .cancel)
        
        #expect(context.alertInfo != nil)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.alertInfo?.primaryButton.action?() // Save
        try await deferred.fulfill()
    }
    
    // PG_CHANGED
    
    // MARK: - Phonebook Consent Tests
    
    @Test
    mutating func phoneBookConsentTypeDidChangeWhenModified() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             phoneBookConsentType: .full))
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(context.phoneBookConsentType == .full)
        #expect(!context.viewState.phoneBookConsentTypeDidChange)
        
        context.phoneBookConsentType = .limited
        
        #expect(context.viewState.phoneBookConsentTypeDidChange)
    }
    
    @Test
    mutating func phoneBookConsentTypeChangeEnablesSave() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             phoneBookConsentType: .full))
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(!context.viewState.canSave)
        
        context.phoneBookConsentType = .none
        
        #expect(context.viewState.canSave)
    }
    
    @Test
    mutating func saveCallsSetPhoneBookConsentType() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             phoneBookConsentType: .full))
        clientProxy.setPhoneBookConsentTypeReturnValue = .success(())
        
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        context.phoneBookConsentType = .limited
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        
        context.send(viewAction: .save)
        
        try await deferred.fulfill()
        
        #expect(clientProxy.setPhoneBookConsentTypeCalled)
        #expect(clientProxy.setPhoneBookConsentTypeReceivedType == .limited)
    }
    
    @Test
    mutating func saveDoesNotCallSetPhoneBookConsentTypeWhenUnchanged() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             phoneBookConsentType: .full))
        clientProxy.setUserDisplayNameReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        // Change name but not consent type
        context.name = "New Name"
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        
        context.send(viewAction: .save)
        
        try await deferred.fulfill()
        
        #expect(!clientProxy.setPhoneBookConsentTypeCalled)
    }
    
    @Test
    mutating func phoneBookConsentTypeDefaultsToFullWhenNil() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             phoneBookConsentType: nil))
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(context.phoneBookConsentType == .default)
    }
    
    // MARK: - Function Field Tests
    
    @Test
    mutating func functionNotSentWhenNilFromBackendAndUntouched() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             function: nil,
                                                             phoneBookConsentType: .full))
        clientProxy.setUserDisplayNameReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        // Function binding should be nil (untouched)
        #expect(context.function == nil)
        // Display should show empty string since backend is nil
        #expect(context.viewState.displayFunction == "")
        // Should not be marked as changed
        #expect(!context.viewState.functionDidChange)
        
        // Change name to enable save
        context.name = "New Name"
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.send(viewAction: .save)
        try await deferred.fulfill()
        
        // setUserFunction should NOT have been called
        #expect(!clientProxy.setUserFunctionCalled)
    }
    
    @Test
    mutating func functionSentWhenExplicitlyEdited() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             function: nil,
                                                             phoneBookConsentType: .full))
        clientProxy.setUserFunctionReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        // User explicitly types in the function field
        context.function = "Developer"
        
        #expect(context.viewState.functionDidChange)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.send(viewAction: .save)
        try await deferred.fulfill()
        
        // setUserFunction SHOULD have been called
        #expect(clientProxy.setUserFunctionCalled)
        #expect(clientProxy.setUserFunctionReceivedFunction == "Developer")
    }
    
    @Test
    mutating func functionNotChangedWhenSetToSameValue() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@test:matrix.org",
                                                             displayName: "Test User",
                                                             avatarURL: nil,
                                                             function: "Manager",
                                                             phoneBookConsentType: .full))
        clientProxy.setUserDisplayNameReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        // User types the same value as backend
        context.function = "Manager"
        
        // Should not be considered changed
        #expect(!context.viewState.functionDidChange)
        
        // Change name to enable save
        context.name = "New Name"
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.send(viewAction: .save)
        try await deferred.fulfill()
        
        // setUserFunction should NOT have been called
        #expect(!clientProxy.setUserFunctionCalled)
    }
    
    // MARK: - Character Limit Tests
    
    @Test
    func displayNameAtTheLimitCanBeSaved() {
        context.name = String(repeating: "a", count: UserDetailsEditScreenViewState.maxDisplayNameLength)
        
        #expect(context.viewState.displayNameLength.charactersOverLimit == 0)
        #expect(!context.viewState.hasFieldOverLimit)
        #expect(context.viewState.canSave)
    }
    
    @Test
    func displayNameOverTheLimitBlocksSaving() {
        context.name = String(repeating: "a", count: UserDetailsEditScreenViewState.maxDisplayNameLength + 3)
        
        #expect(context.viewState.displayNameLength.charactersOverLimit == 3)
        #expect(context.viewState.hasFieldOverLimit)
        // The changes are still unsaved, so the screen keeps warning about them on the way out.
        #expect(context.viewState.hasUnsavedChanges)
        #expect(!context.viewState.canSave)
    }
    
    @Test
    func displayNameIsNotTruncated() {
        let name = String(repeating: "a", count: 60)
        context.name = name
        
        #expect(context.name == name)
        #expect(context.viewState.displayNameLength.errorDescription != nil)
    }
    
    @Test
    func functionOverTheLimitBlocksSaving() {
        context.name = "name"
        context.function = String(repeating: "b", count: UserDetailsEditScreenViewState.maxFunctionLength + 1)
        
        #expect(context.viewState.functionLength.charactersOverLimit == 1)
        #expect(context.viewState.hasFieldOverLimit)
        #expect(!context.viewState.canSave)
    }
    
    @Test
    func counterOnlyAppearsNearTheLimit() {
        context.name = String(repeating: "a", count: 39)
        #expect(context.viewState.displayNameLength.counterDescription == nil)
        #expect(context.viewState.displayNameLength.errorDescription == nil)
        
        context.name = String(repeating: "a", count: 40)
        #expect(context.viewState.displayNameLength.counterDescription != nil)
        #expect(context.viewState.displayNameLength.errorDescription == nil)
        
        context.name = String(repeating: "a", count: 51)
        #expect(context.viewState.displayNameLength.counterDescription == nil)
        #expect(context.viewState.displayNameLength.errorDescription != nil)
    }
    
    @Test
    mutating func saveIsIgnoredWhileOverTheLimit() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.setUserDisplayNameReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        context.name = String(repeating: "a", count: UserDetailsEditScreenViewState.maxDisplayNameLength + 1)
        context.send(viewAction: .save)
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(!clientProxy.setUserDisplayNameCalled)
    }
    
    @Test
    mutating func unsavedChangesAlertDoesNotSaveWhileOverTheLimit() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.setUserDisplayNameReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        context.name = String(repeating: "a", count: UserDetailsEditScreenViewState.maxDisplayNameLength + 1)
        context.send(viewAction: .cancel)
        
        #expect(context.alertInfo != nil)
        
        context.alertInfo?.primaryButton.action?() // Save
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(!clientProxy.setUserDisplayNameCalled)
    }
    
    // MARK: - Private
    
    private mutating func setupViewModel(clientProxy: ClientProxyMock) {
        let userIndicatorController = UserIndicatorControllerMock()
        
        let configuration = UserSessionMockConfiguration(clientProxy: clientProxy)
        viewModel = .init(userSession: UserSessionMock(configuration),
                          mediaUploadingPreprocessor: MediaUploadingPreprocessor(appSettings: .volatile()), // PG_CHANGED - ServiceLocator removed upstream
                          userIndicatorController: userIndicatorController)
    }
}
