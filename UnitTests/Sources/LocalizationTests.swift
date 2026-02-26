//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import XCTest

class LocalizationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        Bundle.overrideLocalizations = nil
    }

    /// Test ElementL10n considers app language changes
    func testAppLanguage() {
        // set app language to English
        Bundle.overrideLocalizations = ["en"]

        XCTAssertEqual(L10n.testLanguageIdentifier, "en")

        // PG_CHANGED - replaces Italian language by Dutch as Italian is not supported
        // set app language to Dutch
        Bundle.overrideLocalizations = ["nl"]

        XCTAssertEqual(L10n.testLanguageIdentifier, "nl")
    }

    /// Test fallback language for a language not supported at all
    func testFallbackOnNotSupportedLanguage() {
        //  set app language to something Element don't support at all (chose non existing identifier)
        Bundle.overrideLocalizations = ["xx"]

        XCTAssertEqual(L10n.testLanguageIdentifier, "en")
    }

    /// Test fallback language for a language supported but poorly translated
    func testFallbackOnNotTranslatedKey() {
        //  set app language to something Element supports but use a key that is not translated (we have a key that should never be translated)
        Bundle.overrideLocalizations = ["fr"]

        XCTAssertEqual(L10n.testLanguageIdentifier, "fr")
        XCTAssertEqual(L10n.testUntranslatedDefaultLanguageIdentifier, "en")
    }

    /// Test plurals that ElementL10n considers app language changes
    func testPlurals() {
        //  set app language to English
        Bundle.overrideLocalizations = ["en"]

        // PG_CHANGED
        XCTAssertEqual(L10n.commonMemberCount(1), "1 member")
        XCTAssertEqual(L10n.commonMemberCount(2), "2 members")

        // PG_CHANGED - replaces Italian language by German as Italian is not supported
        //  set app language to German
        Bundle.overrideLocalizations = ["de"]

        XCTAssertEqual(L10n.commonMemberCount(1), "1 Mitglied")
        XCTAssertEqual(L10n.commonMemberCount(2), "2 Mitglieder")
    }

    /// Test plurals fallback language for a language not supported at all
    func testPluralsFallbackOnNotSupportedLanguage() {
        //  set app language to something Element don't support at all ("invalid identifier")
        Bundle.overrideLocalizations = ["xx"]

        // PG_CHANGED
        XCTAssertEqual(L10n.commonMemberCount(1), "1 member")
        XCTAssertEqual(L10n.commonMemberCount(2), "2 members")
    }

    /// Test untranslated strings
    func testUntranslated() {
        XCTAssertEqual(UntranslatedL10n.untranslated, "Untranslated")
        XCTAssertEqual(UntranslatedL10n.untranslatedPlural(1), "One untranslated item")
        XCTAssertEqual(UntranslatedL10n.untranslatedPlural(5), "5 untranslated items")
    }
}
