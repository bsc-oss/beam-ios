//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
// PG_CHANGED — Unit tests for the badge reset migration introduced in v1.0.3.
// The sygnal push gateway was reconfigured to stop sending badge counts, and this
// migration ensures existing users get their app icon badge cleared on upgrade.

@testable import ElementX
import Testing
import Version

final class PgBadgeResetMigrationTests {
    // PG_CHANGED — Test that versions before 1.0.3 trigger the badge reset.
    @Test
    func shouldReset_returnsTrue_forVersionsBefore103() {
        let oldVersions: [Version] = [
            Version(1, 0, 0),
            Version(1, 0, 1),
            Version(1, 0, 2)
        ]

        for oldVersion in oldVersions {
            #expect(PgBadgeResetMigration.shouldReset(from: oldVersion) == true,
                    "Version \(oldVersion) should trigger badge reset")
        }
    }

    // PG_CHANGED — Test that versions 1.0.3 and later do not trigger the reset.
    @Test
    func shouldReset_returnsFalse_forVersion103AndLater() {
        let oldVersions: [Version] = [
            Version(1, 0, 3),
            Version(1, 0, 4),
            Version(1, 1, 0),
            Version(2, 0, 0)
        ]

        for oldVersion in oldVersions {
            #expect(PgBadgeResetMigration.shouldReset(from: oldVersion) == false,
                    "Version \(oldVersion) should NOT trigger badge reset")
        }
    }

    // PG_CHANGED — Test that the target version constant is correctly set to 1.0.3.
    @Test
    func targetVersion_is103() {
        #expect(PgBadgeResetMigration.targetVersion == Version(1, 0, 3))
    }
}
