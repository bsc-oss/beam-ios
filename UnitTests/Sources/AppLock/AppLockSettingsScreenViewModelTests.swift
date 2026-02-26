//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import XCTest

@testable import ElementX

@MainActor
class AppLockSetupSettingsScreenViewModelTests: XCTestCase {
    var appLockService: AppLockServiceProtocol!
    var keychainController: KeychainControllerMock!
    var viewModel: AppLockSetupSettingsScreenViewModelProtocol!
    
    var context: AppLockSetupSettingsScreenViewModelType.Context {
        viewModel.context
    }
    
    override func setUpWithError() throws {
        keychainController = KeychainControllerMock()
        appLockService = AppLockService(keychainController: keychainController, appSettings: AppSettings())
        
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock())
    }

    func testDisablingShowsAlert() {
        // Given a fresh screen with the PIN code enabled.
        let pinCode = "2023"
        keychainController.pinCodeReturnValue = pinCode
        keychainController.containsPINCodeReturnValue = true
        
        XCTAssertNil(context.alertInfo)
        XCTAssertTrue(appLockService.isEnabled)
        
        // When disabling the PIN code lock.
        context.send(viewAction: .disable)
        
        // Then an alert should be shown before disabling it.
        XCTAssertNotNil(context.alertInfo)
        XCTAssertTrue(appLockService.isEnabled)
    }
    
    // MARK: - PG_CHANGED: canRemovePIN tests
    
    func testCanRemovePINWhenNotMandatory() {
        // Given a screen where App Lock is not mandatory
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(isMandatory: false, deviceHasLockScreen: false))
        
        // Then the user should be able to remove the PIN
        XCTAssertTrue(context.viewState.canRemovePIN)
    }
    
    func testCanRemovePINWhenMandatoryButDeviceHasLockScreen() {
        // Given a screen where App Lock is mandatory but device has OS-level security
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(isMandatory: true, deviceHasLockScreen: true))
        
        // Then the user should be able to remove the PIN (device has its own lock)
        XCTAssertTrue(context.viewState.canRemovePIN)
    }
    
    func testCannotRemovePINWhenMandatoryAndNoDeviceLockScreen() {
        // Given a screen where App Lock is mandatory and device has no OS-level security
        viewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(isMandatory: true, deviceHasLockScreen: false))
        
        // Then the user should NOT be able to remove the PIN
        XCTAssertFalse(context.viewState.canRemovePIN)
    }
}
