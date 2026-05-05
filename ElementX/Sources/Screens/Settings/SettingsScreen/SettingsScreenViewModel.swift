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

typealias SettingsScreenViewModelType = StateStoreViewModelV2<SettingsScreenViewState, SettingsScreenViewAction>

class SettingsScreenViewModel: SettingsScreenViewModelType, SettingsScreenViewModelProtocol {
    private let appSettings: AppSettings
    
    private var actionsSubject: PassthroughSubject<SettingsScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<SettingsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol, appSettings: AppSettings, isBugReportServiceEnabled: Bool) {
        self.appSettings = appSettings
        
        super.init(initialViewState: .init(deviceID: userSession.clientProxy.deviceID,
                                           userID: userSession.clientProxy.userID,
                                           showLinkNewDeviceButton: appSettings.linkNewDeviceEnabled,
                                           showAccountDeactivation: userSession.clientProxy.canDeactivateAccount,
                                           showDeveloperOptions: appSettings.developerOptionsEnabled,
                                           showAnalyticsSettings: appSettings.canPromptForAnalytics,
                                           isBugReportServiceEnabled: isBugReportServiceEnabled),
                   mediaProvider: userSession.mediaProvider)
        
        // PG_CHANGED - do not allow enabling of developer options (not stream needed, constant already set in the above .init)
        
        appSettings.$linkNewDeviceEnabled
            .weakAssign(to: \.state.showLinkNewDeviceButton, on: self)
            .store(in: &cancellables)
        
        // PG_CHANGED - replaces /profile/{id}/displayname|avatar_url endpoints by /profile/{id}
        userSession.clientProxy.userProfileProxyPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userProfileProxy, on: self)
            .store(in: &cancellables)
        
        userSession.sessionSecurityStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] securityState in
                guard let self else { return }
                
                switch (securityState.verificationState, securityState.recoveryState) {
                case (.verified, .disabled):
                    state.showSecuritySectionBadge = true
                    state.securitySectionMode = .secureBackup
                case (.verified, .incomplete):
                    state.showSecuritySectionBadge = true
                    state.securitySectionMode = .secureBackup
                case (.unknown, _):
                    state.showSecuritySectionBadge = false
                    state.securitySectionMode = .none
                default:
                    state.showSecuritySectionBadge = false
                    state.securitySectionMode = .secureBackup
                }
            }
            .store(in: &cancellables)
        
        userSession.clientProxy.ignoredUsersPublisher
            .receive(on: DispatchQueue.main)
            .map {
                guard let blockedUsers = $0 else {
                    return false
                }
                
                return !blockedUsers.isEmpty
            }
            .weakAssign(to: \.state.showBlockedUsers, on: self)
            .store(in: &cancellables)
        
        Task {
            // PG_CHANGED - replaces /profile/{id}/displayname|avatar_url endpoints by /profile/{id}
            await userSession.clientProxy.loadUserProfileProxy()
            await state.accountProfileURL = userSession.clientProxy.accountURL(action: .profile)
            await state.accountSessionsListURL = userSession.clientProxy.accountURL(action: .devicesList)
        }
    }
    
    override func process(viewAction: SettingsScreenViewAction) {
        switch viewAction {
        case .close:
            actionsSubject.send(.close)
        case .userDetails:
            actionsSubject.send(.userDetails)
        case .linkNewDevice:
            actionsSubject.send(.linkNewDevice)
        case let .manageAccount(url):
            actionsSubject.send(.manageAccount(url: url))
        case .analytics:
            actionsSubject.send(.analytics)
        case .appLock:
            actionsSubject.send(.appLock)
        case .reportBug:
            actionsSubject.send(.reportBug)
        case .about:
            actionsSubject.send(.about)
        case .blockedUsers:
            actionsSubject.send(.blockedUsers)
        // PG_CHANGED
        case .loginWithQR:
            actionsSubject.send(.loginWithQR)
        case .logout:
            actionsSubject.send(.logout)
        case .secureBackup:
            actionsSubject.send(.secureBackup)
        case .notifications:
            actionsSubject.send(.notifications)
        case .advancedSettings:
            actionsSubject.send(.advancedSettings)
        case .labs:
            actionsSubject.send(.labs)
        // PG_CHANGED - do not allow enabling of developer options
        case .developerOptions:
            actionsSubject.send(.developerOptions)
        case .deactivateAccount:
            actionsSubject.send(.deactivateAccount)
        }
    }
}
