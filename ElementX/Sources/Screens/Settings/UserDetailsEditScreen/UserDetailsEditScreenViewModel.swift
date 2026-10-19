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
        
        let profile = clientProxy.userProfilePublisher.value
        super.init(initialViewState: UserDetailsEditScreenViewState(currentUserProfile: profile,
                                                                    // PG_CHANGED - adds custom profile fields
                                                                    isScreenLoadedFromOnboardingFlow: isScreenLoadedFromOnboardingFlow,
                                                                    selectedAvatarURL: profile.avatarURL,
                                                                    bindings: .init(name: profile.displayName ?? "")),
                   mediaProvider: userSession.mediaProvider)
        
        clientProxy.userProfilePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                guard let self else { return }
                
                state.currentUserProfile = profile
                state.selectedAvatarURL = profile.avatarURL
                state.bindings.name = profile.displayName ?? ""
                // PG_CHANGED - adds custom profile fields
                state.bindings.department = profile.department ?? ""
                // PG_CHANGED - three-tier phonebook consent system
                state.bindings.phoneBookConsentType = profile.phoneBookConsentType ?? .default
            }
            .store(in: &cancellables)
        
        Task {
            await self.clientProxy.loadUserProfileIfNeeded()
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
        // PG_CHANGED - the unsaved changes alert can offer Save while a field is over its character limit.
        // Deliberately narrower than canSave: change detection runs against an asynchronously updated
        // profile, so only the over-limit check is safe to evaluate here.
        guard !state.hasFieldOverLimit else { return }
        
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
                        try await self.saveAvatar()
                    }
                }
                
                if state.nameDidChange {
                    group.addTask {
                        try await self.saveDisplayName()
                    }
                }
                
                // PG_CHANGED - adds custom profile fields
                if state.functionDidChange, let function = state.bindings.function {
                    group.addTask {
                        try await self.saveFunction(function)
                    }
                }
                
                // PG_CHANGED - three-tier phonebook consent system
                if state.phoneBookConsentTypeDidChange {
                    group.addTask {
                        try await self.savePhoneBookConsentType()
                    }
                }
                
                if isScreenLoadedFromOnboardingFlow, state.currentUserProfile.isProfileInitialized != true {
                    group.addTask {
                        await self.markProfileInitialized()
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
    
    private func saveAvatar() async throws {
        if let localMedia = state.localMedia {
            try await clientProxy.setUserAvatar(media: localMedia).get()
        } else if state.selectedAvatarURL == nil {
            try await clientProxy.removeUserAvatar().get()
        }
    }
    
    private func saveDisplayName() async throws {
        try await clientProxy.setUserDisplayName(state.bindings.name).get()
    }
    
    // PG_CHANGED - custom profile fields; isolated helpers keep the non-Sendable clientProxy on the main actor
    private func saveFunction(_ function: String) async throws {
        try await clientProxy.setUserFunction(function).get()
    }
    
    private func savePhoneBookConsentType() async throws {
        try await clientProxy.setPhoneBookConsentType(state.bindings.phoneBookConsentType).get()
    }
    
    private func markProfileInitialized() async {
        do {
            try await clientProxy.setProfileInitialized(true).get()
        } catch {
            MXLog.warning("Failed to set profile initialized: \(error)")
        }
    }
}
