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

@testable import ElementX
import Testing

@MainActor
struct AppLockSetupSettingsScreenViewModelTests {
    var appLockService: AppLockServiceProtocol
    var keychainController: KeychainControllerMock
    var viewModel: AppLockSetupSettingsScreenViewModelProtocol
    
    var context: AppLockSetupSettingsScreenViewModelType.Context {
        viewModel.context
    }
    
    init() {
        keychainController = KeychainControllerMock()
        appLockService = AppLockService(keychainController: keychainController, appSettings: AppSettings())
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock())
    }

    @Test
    func disablingShowsAlert() {
        // Given a fresh screen with the PIN code enabled.
        let pinCode = "2023"
        keychainController.pinCodeReturnValue = pinCode
        keychainController.containsPINCodeReturnValue = true
        
        #expect(context.alertInfo == nil)
        #expect(appLockService.isEnabled)
        
        // When disabling the PIN code lock.
        context.send(viewAction: .disable)
        
        // Then an alert should be shown before disabling it.
        #expect(context.alertInfo != nil)
        #expect(appLockService.isEnabled)
    }
    
    // MARK: - PG_CHANGED: canRemovePIN tests
    
    @Test
    mutating func canRemovePINWhenNotMandatory() {
        // Given a screen where App Lock is not mandatory
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(isMandatory: false, deviceHasLockScreen: false))
        
        // Then the user should be able to remove the PIN
        #expect(context.viewState.canRemovePIN)
    }
    
    @Test
    mutating func canRemovePINWhenMandatoryButDeviceHasLockScreen() {
        // Given a screen where App Lock is mandatory but device has OS-level security
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(isMandatory: true, deviceHasLockScreen: true))
        
        // Then the user should be able to remove the PIN (device has its own lock)
        #expect(context.viewState.canRemovePIN)
    }
    
    @Test
    mutating func cannotRemovePINWhenMandatoryAndNoDeviceLockScreen() {
        // Given a screen where App Lock is mandatory and device has no OS-level security
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(isMandatory: true, deviceHasLockScreen: false))
        
        // Then the user should NOT be able to remove the PIN
        #expect(!context.viewState.canRemovePIN)
    }
}
