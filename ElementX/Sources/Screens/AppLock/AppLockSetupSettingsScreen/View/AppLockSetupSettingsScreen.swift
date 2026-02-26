//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct AppLockSetupSettingsScreen: View {
    @ObservedObject var context: AppLockSetupSettingsScreenViewModel.Context
    
    var body: some View {
        Form {
            Section {
                ListRow(label: .plain(title: L10n.screenAppLockSettingsChangePin),
                        kind: .button { context.send(viewAction: .changePINCode) })
                    .accessibilityIdentifier(A11yIdentifiers.appLockSetupSettingsScreen.changePIN)
                
                // PG_CHANGED
                if context.viewState.canRemovePIN {
                    ListRow(label: .plain(title: L10n.screenAppLockSettingsRemovePin, role: .destructive),
                            kind: .button { context.send(viewAction: .disable) })
                        .accessibilityIdentifier(A11yIdentifiers.appLockSetupSettingsScreen.removePIN)
                }
            } footer: {
                // PG_CHANGED: Show hint when device has no lock screen
                if !context.viewState.canRemovePIN {
                    Text(L10n.pgScreenAppLockSettingsPinMandatoryHint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            
            if context.viewState.supportsBiometrics {
                Section {
                    ListRow(label: .plain(title: context.viewState.enableBiometricsTitle),
                            kind: .toggle($context.enableBiometrics))
                        .onChange(of: context.enableBiometrics) {
                            context.send(viewAction: .enableBiometricsChanged)
                        }
                }
            }
        }
        .compoundList()
        .navigationTitle(L10n.commonScreenLock)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $context.alertInfo)
    }
}

// MARK: - Previews

struct AppLockSetupSettingsScreen_Previews: PreviewProvider, TestablePreview {
    static let faceIDViewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(biometryType: .faceID))
    // PG_CHANGED
    static let noLockScreenViewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(isMandatory: true, deviceHasLockScreen: false, biometryType: .none))
    static let biometricsUnavailableViewModel = AppLockSetupSettingsScreenViewModel(appLockService: AppLockServiceMock.mock(biometryType: .none))
    
    static var previews: some View {
        NavigationStack {
            AppLockSetupSettingsScreen(context: faceIDViewModel.context)
        }
        .previewDisplayName("Face ID")
        
        // PG_CHANGED
        NavigationStack {
            AppLockSetupSettingsScreen(context: noLockScreenViewModel.context)
        }
        .previewDisplayName("No OS screen lock (Mandatory)")
        
        NavigationStack {
            AppLockSetupSettingsScreen(context: biometricsUnavailableViewModel.context)
        }
        .previewDisplayName("PIN only")
    }
}
