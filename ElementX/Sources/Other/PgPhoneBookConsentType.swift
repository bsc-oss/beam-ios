//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Represents the user's privacy preference for how they can be discovered by colleagues.
enum PhoneBookConsentType: String, Codable, CaseIterable, Equatable {
    /// Public address book (recommended) - Anyone can find you by name or email.
    /// Basic profile is immediately visible in search results.
    case full
    
    /// Discreet - findable via email only.
    /// Only findable if someone enters your full and exact email address.
    /// Profile information only visible after you accept an invitation.
    case limited
    
    /// Hidden - findable via BeamID (Matrix ID) only.
    /// Maximum privacy - only findable if someone manually enters your BeamID.
    case none
    
    /// The default consent type for new users.
    static var `default`: PhoneBookConsentType { .full }
    
    /// Returns the localized title for this consent type.
    var title: String {
        switch self {
        case .full:
            L10n.pgScreenEditProfilePhonebookConsentFullTitle
        case .limited:
            L10n.pgScreenEditProfilePhonebookConsentLimitedTitle
        case .none:
            L10n.pgScreenEditProfilePhonebookConsentNoneTitle
        }
    }
    
    /// Returns the localized subtitle for this consent type.
    var subtitle: String {
        switch self {
        case .full:
            L10n.pgScreenEditProfilePhonebookConsentFullSubtitle
        case .limited:
            L10n.pgScreenEditProfilePhonebookConsentLimitedSubtitle
        case .none:
            L10n.pgScreenEditProfilePhonebookConsentNoneSubtitle
        }
    }
    
    /// Returns the localized bullet points for this consent type.
    var bulletPoints: [String] {
        switch self {
        case .full:
            [
                L10n.pgScreenEditProfilePhonebookConsentFullBullet1,
                L10n.pgScreenEditProfilePhonebookConsentFullBullet2
            ]
        case .limited:
            [
                L10n.pgScreenEditProfilePhonebookConsentLimitedBullet1,
                L10n.pgScreenEditProfilePhonebookConsentLimitedBullet2
            ]
        case .none:
            [
                L10n.pgScreenEditProfilePhonebookConsentNoneBullet1,
                L10n.pgScreenEditProfilePhonebookConsentNoneBullet2
            ]
        }
    }
    
    /// Returns the localized warning text for this consent type, if any.
    var warningText: String? {
        switch self {
        case .full:
            nil
        case .limited:
            L10n.pgScreenEditProfilePhonebookConsentLimitedWarning
        case .none:
            L10n.pgScreenEditProfilePhonebookConsentNoneWarning
        }
    }
    
    /// Converts from SDK's FfiPhoneBookConsent type.
    init?(ffiConsent: FfiPhoneBookConsent) {
        switch ffiConsent {
        case .full:
            self = .full
        case .limited:
            self = .limited
        case .none:
            self = .none
        }
    }
    
    /// Converts to SDK's FfiPhoneBookConsent type.
    var ffiConsent: FfiPhoneBookConsent {
        switch self {
        case .full:
            .full
        case .limited:
            .limited
        case .none:
            .none
        }
    }
}
