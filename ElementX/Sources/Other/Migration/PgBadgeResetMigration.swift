//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
// PG_CHANGED — Migration that resets the app icon badge count to 0 for users
// upgrading to v1.0.3. The sygnal push gateway was reconfigured to stop sending
// badge counts (the feature was buggy), but existing users who already had a
// badge pinned to their app icon would never see it cleared.

import UserNotifications
import Version

/// PG_CHANGED — Badge reset migration for v1.0.3 upgrade.
enum PgBadgeResetMigration {
    /// Version threshold — users upgrading from before this version get their badge reset.
    static let targetVersion = Version(1, 0, 3)

    /// Returns `true` when the badge should be reset for the given previous app version.
    static func shouldReset(from oldVersion: Version) -> Bool {
        oldVersion < targetVersion
    }

    /// Resets the app icon badge count to 0.
    static func reset() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
