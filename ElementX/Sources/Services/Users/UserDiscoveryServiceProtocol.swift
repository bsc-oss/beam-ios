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

enum UserDiscoveryErrorType: Error {
    case failedSearchingUsers
}

// sourcery: AutoMockable
protocol UserDiscoveryServiceProtocol {
    // PG_CHANGED - the whole result, so callers can tell a cache-only or refused search from a complete one
    func searchProfiles(with searchQuery: String) async -> Result<SearchUsersResults, UserDiscoveryErrorType>
}
