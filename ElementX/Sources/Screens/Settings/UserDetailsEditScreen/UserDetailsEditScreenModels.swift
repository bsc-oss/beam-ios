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

import Foundation

enum UserDetailsEditScreenViewModelAction {
    case dismiss
    case displayCameraPicker
    case displayMediaPicker
    case displayFilePicker
    // PG_CHANGED - adds custom profile fields
    case save
}

struct UserDetailsEditScreenViewState: BindableState {
    let userID: String
    // PG_CHANGED - adds custom profile fields
    let isScreenLoadedFromOnboardingFlow: Bool
    var userProfile: UserProfileProxy?
    
    // PG_CHANGED - omitted upstream's unused currentAvatarURL (PG screen uses userProfile / selectedAvatarURL)
    var canEditAvatar = true
    var canEditDisplayName = true
    var selectedAvatarURL: URL?
    
    var localMedia: MediaInfo?
    
    var bindings: UserDetailsEditScreenViewStateBindings
    
    var nameDidChange: Bool {
        bindings.name != userProfile?.displayName
    }
    
    // PG_CHANGED - adds custom profile fields
    var functionDidChange: Bool {
        // Only consider changed if binding is non-nil (user explicitly set a value)
        // and it differs from the backend value
        guard let bindingFunction = bindings.function else {
            return false
        }
        return bindingFunction != (userProfile?.function ?? "")
    }
    
    // PG_CHANGED - three-tier phonebook consent system
    var phoneBookConsentTypeDidChange: Bool {
        bindings.phoneBookConsentType != userProfile?.phoneBookConsentType
    }

    var avatarDidChange: Bool {
        localMedia != nil || selectedAvatarURL != userProfile?.avatarURL
    }
    
    // PG_CHANGED - adds custom profile fields
    var canSave: Bool {
        !bindings.name.isEmpty
            && (isScreenLoadedFromOnboardingFlow || avatarDidChange || nameDidChange || functionDidChange || phoneBookConsentTypeDidChange)
    }
    
    var showDeleteImageAction: Bool {
        localMedia != nil || selectedAvatarURL != nil
    }
    
    // PG_CHANGED - display function from binding if user edited, otherwise from profile
    var displayFunction: String {
        bindings.function ?? userProfile?.function ?? ""
    }
}

struct UserDetailsEditScreenViewStateBindings {
    var name = ""
    var showMediaSheet = false
    // PG_CHANGED - adds custom profile fields
    var department = ""
    var function: String?
    // PG_CHANGED - three-tier phonebook consent system
    var phoneBookConsentType: PhoneBookConsentType = .default
    
    var alertInfo: AlertInfo<UserDetailsEditScreenAlertType>?
}

enum UserDetailsEditScreenAlertType {
    case failedProcessingMedia
    case unsavedChanges
    case saveError
    case unknown
}

enum UserDetailsEditScreenViewAction {
    case cancel
    case save
    case presentMediaSource
    case displayCameraPicker
    case displayMediaPicker
    case displayFilePicker
    case removeImage
}
