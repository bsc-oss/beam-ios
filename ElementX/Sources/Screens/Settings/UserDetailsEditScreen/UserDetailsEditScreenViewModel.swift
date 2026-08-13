//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Combine
import SwiftUI

typealias UserDetailsEditScreenViewModelType = StateStoreViewModelV2<UserDetailsEditScreenViewState, UserDetailsEditScreenViewAction>

class UserDetailsEditScreenViewModel: UserDetailsEditScreenViewModelType, UserDetailsEditScreenViewModelProtocol {
    private let actionsSubject: PassthroughSubject<UserDetailsEditScreenViewModelAction, Never> = .init()
    private let clientProxy: ClientProxyProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    private let mediaUploadingPreprocessor: MediaUploadingPreprocessor
    private let isScreenLoadedFromOnboardingFlow: Bool
    
    var actions: AnyPublisher<UserDetailsEditScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(userSession: UserSessionProtocol,
         mediaUploadingPreprocessor: MediaUploadingPreprocessor,
         userIndicatorController: UserIndicatorControllerProtocol,
         isScreenLoadedFromOnboardingFlow: Bool = false) {
        clientProxy = userSession.clientProxy
        self.mediaUploadingPreprocessor = mediaUploadingPreprocessor
        self.userIndicatorController = userIndicatorController
        // PG_CHANGED - adds custom profile fields
        self.isScreenLoadedFromOnboardingFlow = isScreenLoadedFromOnboardingFlow
        
        super.init(initialViewState: UserDetailsEditScreenViewState(userID: clientProxy.userID,
                                                                    // PG_CHANGED - adds custom profile fields
                                                                    isScreenLoadedFromOnboardingFlow: isScreenLoadedFromOnboardingFlow,
                                                                    bindings: .init()), mediaProvider: userSession.mediaProvider)
        
        // PG_CHANGED - replaces /profile/{id}/displayname|avatar_url endpoints by /profile/{id} and adds custom profile fields
        clientProxy.userProfileProxyPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userProfile in
                guard let self else { return }
                
                state.selectedAvatarURL = userProfile?.avatarURL
                state.userProfile = userProfile
                state.bindings.name = userProfile?.displayName ?? ""
                state.bindings.department = userProfile?.department ?? ""
                // PG_CHANGED - three-tier phonebook consent system
                state.bindings.phoneBookConsentType = userProfile?.phoneBookConsentType ?? .default
            }
            .store(in: &cancellables)

        Task {
            // PG_CHANGED - replaces /profile/{id}/displayname|avatar_url endpoints by /profile/{id}
            await self.clientProxy.loadUserProfileProxy()
            state.canEditAvatar = await clientProxy.capabilities.canChangeAvatar()
            state.canEditDisplayName = await clientProxy.capabilities.canChangeDisplayName()
        }
    }
    
    // MARK: - Public
    
    override func process(viewAction: UserDetailsEditScreenViewAction) {
        switch viewAction {
        case .cancel:
            showUnsavedChangesAlert() // The cancel button is only shown when there are unsaved changes.
        case .save:
            Task { await saveUserDetails() }
        case .presentMediaSource:
            state.bindings.showMediaSheet = true
        case .displayCameraPicker:
            actionsSubject.send(.displayCameraPicker)
        case .displayMediaPicker:
            actionsSubject.send(.displayMediaPicker)
        case .displayFilePicker:
            actionsSubject.send(.displayFilePicker)
        case .removeImage:
            state.localMedia = nil
            state.selectedAvatarURL = nil
        }
    }
    
    func didSelectMediaURL(url: URL) {
        Task {
            let userIndicatorID = UUID().uuidString
            defer { userIndicatorController.retractIndicatorWithId(userIndicatorID) }
            userIndicatorController.submitIndicator(UserIndicator(id: userIndicatorID,
                                                                  type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                                  title: L10n.commonLoading,
                                                                  persistent: true))
            
            guard case let .success(maxUploadSize) = await clientProxy.maxMediaUploadSize else {
                MXLog.error("Failed to get max upload size")
                state.bindings.alertInfo = .init(id: .unknown)
                return
            }
            let mediaResult = await mediaUploadingPreprocessor.processMedia(at: url, maxUploadSize: maxUploadSize)
            
            switch mediaResult {
            case .success(.image):
                state.localMedia = try? mediaResult.get()
            case .failure, .success:
                state.bindings.alertInfo = .init(id: .failedProcessingMedia)
            }
        }
    }
    
    // MARK: - Private
    
    private func showUnsavedChangesAlert() {
        state.bindings.alertInfo = .init(id: .unsavedChanges,
                                         title: L10n.dialogUnsavedChangesTitle,
                                         message: L10n.dialogUnsavedChangesDescription,
                                         primaryButton: .init(title: L10n.actionSave) { Task { await self.saveUserDetails() } },
                                         secondaryButton: .init(title: L10n.actionDiscard, role: .cancel) { self.actionsSubject.send(.dismiss) })
    }
    
    private func saveUserDetails() async {
        let userIndicatorID = UUID().uuidString
        defer {
            userIndicatorController.retractIndicatorWithId(userIndicatorID)
        }
        userIndicatorController.submitIndicator(UserIndicator(id: userIndicatorID,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: true, allowsInteraction: false),
                                                              title: L10n.screenEditProfileUpdatingDetails,
                                                              persistent: true))
        
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                if state.avatarDidChange {
                    group.addTask {
                        if let localMedia = await self.state.localMedia {
                            try await self.clientProxy.setUserAvatar(media: localMedia).get()
                        } else if await self.state.selectedAvatarURL == nil {
                            try await self.clientProxy.removeUserAvatar().get()
                        }
                    }
                }
                
                if state.nameDidChange {
                    group.addTask {
                        try await self.clientProxy.setUserDisplayName(self.state.bindings.name).get()
                    }
                }

                // PG_CHANGED - adds custom profile fields
                if state.functionDidChange, let function = state.bindings.function {
                    group.addTask {
                        try await self.clientProxy.setUserFunction(function).get()
                    }
                }
                
                // PG_CHANGED - three-tier phonebook consent system
                if state.phoneBookConsentTypeDidChange {
                    group.addTask {
                        try await self.clientProxy.setPhoneBookConsentType(self.state.bindings.phoneBookConsentType).get()
                    }
                }

                if isScreenLoadedFromOnboardingFlow, state.userProfile?.isProfileInitialized != true {
                    group.addTask {
                        do {
                            try await self.clientProxy.setProfileInitialized(true).get()
                        } catch {
                            MXLog.warning("Failed to set profile initialized: \(error)")
                        }
                    }
                }

                // PG_CHANGED - END
                
                try await group.waitForAll()

                // PG_CHANGED - fixes issue where save button would remain enabled after avatar change is saved successfully.
                state.localMedia = nil
            }
            
            // PG_CHANGED - profile onboarding screen
            if isScreenLoadedFromOnboardingFlow {
                actionsSubject.send(.save)
            }
            
            actionsSubject.send(.dismiss)
        } catch {
            state.bindings.alertInfo = .init(id: .saveError,
                                             title: L10n.screenEditProfileErrorTitle,
                                             message: L10n.screenEditProfileError)
        }
    }
}
