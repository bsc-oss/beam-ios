//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MatrixRustSDK
import XCTest

@testable import ElementX

@MainActor
class UserDetailsEditScreenViewModelTests: XCTestCase {
    var viewModel: UserDetailsEditScreenViewModel!
    
    var userIndicatorController: UserIndicatorControllerMock!
    
    var context: UserDetailsEditScreenViewModelType.Context {
        viewModel.context
    }
    
    // MARK: - Basic Tests
    
    func testCannotSaveOnLanding() {
        setupViewModel()
        XCTAssertFalse(context.viewState.canSave)
    }
    
    func testNameDidChange() {
        setupViewModel()
        context.name = "name"
        XCTAssertTrue(context.viewState.nameDidChange)
        XCTAssertTrue(context.viewState.canSave)
    }
    
    func testEmptyNameCannotBeSaved() {
        setupViewModel()
        context.name = ""
        XCTAssertFalse(context.viewState.canSave)
    }
    
    func testAvatarPickerShowsSheet() {
        setupViewModel()
        context.name = "name"
        XCTAssertFalse(context.showMediaSheet)
        context.send(viewAction: .presentMediaSource)
        XCTAssertTrue(context.showMediaSheet)
    }
    
    func testSave() async throws {
        // PG_CHANGED
        let clientProxy = ClientProxyMock(.init())

        setupViewModel(clientProxy: clientProxy)
        
        // Saving shouldn't dismiss this screen (or trigger any other action).
        let deferred = deferFailure(viewModel.actions, timeout: 1) { _ in true }
        
        context.name = "name"
        context.send(viewAction: .save)
        
        try await deferred.fulfill()
    }
    
    func testCancelWithChangesAndDiscard() async throws {
        setupViewModel()
        context.name = "name"
        XCTAssertTrue(context.viewState.canSave)
        XCTAssertNil(context.alertInfo)
        
        context.send(viewAction: .cancel)
        
        XCTAssertNotNil(context.alertInfo)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.alertInfo?.secondaryButton?.action?() // Discard
        try await deferred.fulfill()
    }
    
    func testCancelWithChangesAndSave() async throws {
        // PG_CHANGED
        let clientProxy = ClientProxyMock(.init())

        setupViewModel(clientProxy: clientProxy)
        
        context.name = "name"
        
        XCTAssertTrue(context.viewState.canSave)
        XCTAssertNil(context.alertInfo)
        
        context.send(viewAction: .cancel)
        
        XCTAssertNotNil(context.alertInfo)
        
        let deferred = deferFulfillment(viewModel.actions) { $0 == .dismiss }
        context.alertInfo?.primaryButton.action?() // Save
        try await deferred.fulfill()
    }

    // PG_CHANGED
    
    // MARK: - Phonebook Consent Tests
    
    func testPhoneBookConsentTypeDidChangeWhenModified() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
                                                                       displayName: "Test User",
                                                                       avatarURL: nil,
                                                                       phoneBookConsentType: .full))
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(context.phoneBookConsentType, .full)
        XCTAssertFalse(context.viewState.phoneBookConsentTypeDidChange)
        
        context.phoneBookConsentType = .limited
        
        XCTAssertTrue(context.viewState.phoneBookConsentTypeDidChange)
    }
    
    func testPhoneBookConsentTypeChangeEnablesSave() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
                                                                       displayName: "Test User",
                                                                       avatarURL: nil,
                                                                       phoneBookConsentType: .full))
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        XCTAssertFalse(context.viewState.canSave)
        
        context.phoneBookConsentType = .none
        
        XCTAssertTrue(context.viewState.canSave)
    }
    
    func testSaveCallsSetPhoneBookConsentType() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
                                                                       displayName: "Test User",
                                                                       avatarURL: nil,
                                                                       phoneBookConsentType: .full))
        clientProxy.setPhoneBookConsentTypeReturnValue = .success(())
        
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        context.phoneBookConsentType = .limited
        
        // Saving shouldn't dismiss this screen
        let deferred = deferFailure(viewModel.actions, timeout: 1) { _ in true }
        
        context.send(viewAction: .save)
        
        try await deferred.fulfill()
        
        XCTAssertTrue(clientProxy.setPhoneBookConsentTypeCalled)
        XCTAssertEqual(clientProxy.setPhoneBookConsentTypeReceivedType, .limited)
    }
    
    func testSaveDoesNotCallSetPhoneBookConsentTypeWhenUnchanged() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
                                                                       displayName: "Test User",
                                                                       avatarURL: nil,
                                                                       phoneBookConsentType: .full))
        clientProxy.setUserDisplayNameReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        // Change name but not consent type
        context.name = "New Name"
        
        let deferred = deferFailure(viewModel.actions, timeout: 1) { _ in true }
        
        context.send(viewAction: .save)
        
        try await deferred.fulfill()
        
        XCTAssertFalse(clientProxy.setPhoneBookConsentTypeCalled)
    }
    
    func testPhoneBookConsentTypeDefaultsToFullWhenNil() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
                                                                       displayName: "Test User",
                                                                       avatarURL: nil,
                                                                       phoneBookConsentType: nil))
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        XCTAssertEqual(context.phoneBookConsentType, .default)
    }
    
    // MARK: - Function Field Tests
    
    func testFunctionNotSentWhenNilFromBackendAndUntouched() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
                                                                       displayName: "Test User",
                                                                       avatarURL: nil,
                                                                       function: nil,
                                                                       phoneBookConsentType: .full))
        clientProxy.setUserDisplayNameReturnValue = .success(())
        setupViewModel(clientProxy: clientProxy)
        
        // Wait for the profile to load
        try await Task.sleep(for: .milliseconds(100))
        
        // Function binding should be nil (untouched)
        XCTAssertNil(context.function)
        // Display should show empty string since backend is nil
        XCTAssertEqual(context.viewState.displayFunction, "")
        // Should not be marked as changed
        XCTAssertFalse(context.viewState.functionDidChange)
        
        // Change name to enable save
        context.name = "New Name"
        
        let deferred = deferFailure(viewModel.actions, timeout: 1) { _ in true }
        context.send(viewAction: .save)
        try await deferred.fulfill()
        
        // setUserFunction should NOT have been called
        XCTAssertFalse(clientProxy.setUserFunctionCalled)
    }
    
    func testFunctionSentWhenExplicitlyEdited() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
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
        
        XCTAssertTrue(context.viewState.functionDidChange)
        
        let deferred = deferFailure(viewModel.actions, timeout: 1) { _ in true }
        context.send(viewAction: .save)
        try await deferred.fulfill()
        
        // setUserFunction SHOULD have been called
        XCTAssertTrue(clientProxy.setUserFunctionCalled)
        XCTAssertEqual(clientProxy.setUserFunctionReceivedFunction, "Developer")
    }
    
    func testFunctionNotChangedWhenSetToSameValue() async throws {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.userProfileProxyPublisher = .init(UserProfileProxy(userID: "@test:matrix.org",
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
        XCTAssertFalse(context.viewState.functionDidChange)
        
        // Change name to enable save
        context.name = "New Name"
        
        let deferred = deferFailure(viewModel.actions, timeout: 1) { _ in true }
        context.send(viewAction: .save)
        try await deferred.fulfill()
        
        // setUserFunction should NOT have been called
        XCTAssertFalse(clientProxy.setUserFunctionCalled)
    }

    // MARK: - Private
    
    private func setupViewModel() {
        userIndicatorController = UserIndicatorControllerMock.default
        
        viewModel = .init(userSession: UserSessionMock(.init()),
                          mediaUploadingPreprocessor: MediaUploadingPreprocessor(appSettings: ServiceLocator.shared.settings),
                          userIndicatorController: userIndicatorController)
    }
    
    private func setupViewModel(clientProxy: ClientProxyMock) {
        userIndicatorController = UserIndicatorControllerMock.default

        let configuration = UserSessionMockConfiguration(clientProxy: clientProxy)
        viewModel = .init(userSession: UserSessionMock(configuration),
                          mediaUploadingPreprocessor: MediaUploadingPreprocessor(appSettings: ServiceLocator.shared.settings),
                          userIndicatorController: userIndicatorController)
    }
}
