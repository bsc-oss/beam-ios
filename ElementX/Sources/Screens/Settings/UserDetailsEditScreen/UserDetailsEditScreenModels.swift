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
    var currentUserProfile: UserProfile
    // PG_CHANGED - adds custom profile fields
    let isScreenLoadedFromOnboardingFlow: Bool
    
    // PG_CHANGED - omitted upstream's unused currentAvatarURL (PG screen uses userProfile / selectedAvatarURL)
    var canEditAvatar = true
    var canEditDisplayName = true
    
    var selectedAvatarURL: URL?
    var localMedia: MediaInfo?
    
    var bindings: UserDetailsEditScreenViewStateBindings
    
    var nameDidChange: Bool {
        bindings.name != currentUserProfile.displayName
    }
    
    var avatarDidChange: Bool {
        localMedia != nil || selectedAvatarURL != currentUserProfile.avatarURL
    }
    
    // PG_CHANGED - adds custom profile fields
    var functionDidChange: Bool {
        // Only consider changed if binding is non-nil (user explicitly set a value)
        // and it differs from the backend value
        guard let bindingFunction = bindings.function else {
            return false
        }
        return bindingFunction != (currentUserProfile.function ?? "")
    }
    
    // PG_CHANGED - three-tier phonebook consent system
    var phoneBookConsentTypeDidChange: Bool {
        bindings.phoneBookConsentType != currentUserProfile.phoneBookConsentType
    }
    
    // PG_CHANGED - adds custom profile fields
    /// Whether there is anything worth warning the user about before they leave the screen.
    var hasUnsavedChanges: Bool {
        !bindings.name.isEmpty
            && (isScreenLoadedFromOnboardingFlow || avatarDidChange || nameDidChange || functionDidChange || phoneBookConsentTypeDidChange)
    }
    
    // PG_CHANGED - values over the character limit are kept as typed, but they can't be saved
    var canSave: Bool {
        hasUnsavedChanges && !hasFieldOverLimit
    }
    
    var showDeleteImageAction: Bool {
        localMedia != nil || selectedAvatarURL != nil
    }
    
    // PG_CHANGED - display function from binding if user edited, otherwise from profile
    var displayFunction: String {
        bindings.function ?? currentUserProfile.function ?? ""
    }
    
    // PG_CHANGED - the backend rejects display names and roles longer than this, so the client enforces it too
    static let maxDisplayNameLength = 50
    static let maxFunctionLength = 50
    
    var displayNameLength: UserDetailsEditScreenFieldLength {
        .init(bindings.name, maxLength: Self.maxDisplayNameLength)
    }
    
    var functionLength: UserDetailsEditScreenFieldLength {
        .init(displayFunction, maxLength: Self.maxFunctionLength)
    }
    
    /// Saving is blocked, rather than the input truncated, so that the value can be edited down.
    var hasFieldOverLimit: Bool {
        displayNameLength.isOverLimit || functionLength.isOverLimit
    }
}

// PG_CHANGED - profile fields have a maximum length; values over it are kept as typed and flagged, never truncated.
struct UserDetailsEditScreenFieldLength: Equatable {
    /// The counter only appears once the value has entered the last 20% of its limit.
    private static let counterVisibilityRatio = 0.8
    
    let count: Int
    let maxLength: Int
    
    init(_ value: String, maxLength: Int) {
        count = value.count
        self.maxLength = maxLength
    }
    
    var charactersOverLimit: Int {
        max(count - maxLength, 0)
    }
    
    var isOverLimit: Bool {
        charactersOverLimit > 0
    }
    
    var isNearLimit: Bool {
        Double(count) >= Double(maxLength) * Self.counterVisibilityRatio
    }
    
    /// Shown under the field, in the critical style, when the value is too long.
    var errorDescription: String? {
        isOverLimit ? L10n.pgScreenEditProfileCharactersOverLimit(charactersOverLimit) : nil
    }
    
    /// Shown under the field while the value approaches its limit.
    var counterDescription: String? {
        guard isNearLimit, !isOverLimit else { return nil }
        return L10n.pgScreenEditProfileCharacterCounter(count, maxLength)
    }
    
    /// Spoken in place of the counter, which doesn't read well out loud.
    var counterAccessibilityLabel: String {
        L10n.pgA11yProfileFieldCharactersCount(count, maxLength)
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
