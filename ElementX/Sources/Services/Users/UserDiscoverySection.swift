//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-09-25

import Foundation

struct UserDiscoverySection {
    let type: UserDiscoverySectionType
    let users: [UserProfile]
    // PG_CHANGED - see `SearchUsersResults`
    var knownFromRoomUserIDs: Set<String> = []
    var serverError: SearchUsersServerError?
    
    var title: String? {
        switch type {
        case .searchResult:
            return nil
        case .suggestions:
            return users.isEmpty ? nil : L10n.commonSuggestions
        }
    }
    
    // PG_CHANGED
    var isRateLimited: Bool {
        serverError == .rateLimited
    }
    
    // PG_CHANGED - a refused search says nothing about who would have matched
    var emptyResultsText: String {
        isRateLimited ? L10n.pgCommonSearchRateLimited : L10n.commonNoResults
    }
    
    // PG_CHANGED - shown above results served from the local cache only
    var notice: String? {
        guard !users.isEmpty, let serverError else { return nil }
        
        return switch serverError {
        case .rateLimited: L10n.pgCommonSearchLocalResultsOnlyRateLimited
        case .unavailable: L10n.pgCommonSearchLocalResultsOnly
        }
    }
}

// PG_CHANGED
extension UserDiscoverySection {
    init(searchResults: SearchUsersResults) {
        self.init(type: .searchResult,
                  users: searchResults.results,
                  knownFromRoomUserIDs: searchResults.knownFromRoomUserIDs,
                  serverError: searchResults.serverError)
    }
}

enum UserDiscoverySectionType: Equatable {
    case searchResult
    case suggestions
}
