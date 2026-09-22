//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDK
import XCTest

class PhoneBookConsentTypeTests: XCTestCase {
    // MARK: - Raw Value Tests
    
    func testRawValues() {
        XCTAssertEqual(PhoneBookConsentType.full.rawValue, "full")
        XCTAssertEqual(PhoneBookConsentType.limited.rawValue, "limited")
        XCTAssertEqual(PhoneBookConsentType.none.rawValue, "none")
    }
    
    func testInitFromRawValue() {
        XCTAssertEqual(PhoneBookConsentType(rawValue: "full"), .full)
        XCTAssertEqual(PhoneBookConsentType(rawValue: "limited"), .limited)
        XCTAssertEqual(PhoneBookConsentType(rawValue: "none"), PhoneBookConsentType.none)
        XCTAssertNil(PhoneBookConsentType(rawValue: "invalid"))
    }
    
    // MARK: - Default Value Test
    
    func testDefaultValue() {
        XCTAssertEqual(PhoneBookConsentType.default, .full)
    }
    
    // MARK: - CaseIterable Tests
    
    func testAllCases() {
        XCTAssertEqual(PhoneBookConsentType.allCases.count, 3)
        XCTAssertTrue(PhoneBookConsentType.allCases.contains(.full))
        XCTAssertTrue(PhoneBookConsentType.allCases.contains(.limited))
        XCTAssertTrue(PhoneBookConsentType.allCases.contains(.none))
    }
    
    // MARK: - Localized Content Tests
    
    func testTitlesAreNotEmpty() {
        for consentType in PhoneBookConsentType.allCases {
            XCTAssertFalse(consentType.title.isEmpty, "\(consentType) title should not be empty")
        }
    }
    
    func testSubtitlesAreNotEmpty() {
        for consentType in PhoneBookConsentType.allCases {
            XCTAssertFalse(consentType.subtitle.isEmpty, "\(consentType) subtitle should not be empty")
        }
    }
    
    func testBulletPointsAreNotEmpty() {
        for consentType in PhoneBookConsentType.allCases {
            XCTAssertFalse(consentType.bulletPoints.isEmpty, "\(consentType) should have bullet points")
            for bullet in consentType.bulletPoints {
                XCTAssertFalse(bullet.isEmpty, "\(consentType) bullet point should not be empty")
            }
        }
    }
    
    // MARK: - Warning Text Tests
    
    func testWarningTextForFullIsNil() {
        XCTAssertNil(PhoneBookConsentType.full.warningText)
    }
    
    func testWarningTextForLimitedIsNotNil() throws {
        XCTAssertNotNil(PhoneBookConsentType.limited.warningText)
        XCTAssertFalse(try XCTUnwrap(PhoneBookConsentType.limited.warningText?.isEmpty))
    }
    
    func testWarningTextForNoneIsNotNil() throws {
        XCTAssertNotNil(PhoneBookConsentType.none.warningText)
        XCTAssertFalse(try XCTUnwrap(PhoneBookConsentType.none.warningText?.isEmpty))
    }
    
    // MARK: - FFI Conversion Tests
    
    func testInitFromFfiConsentFull() {
        let consentType = PhoneBookConsentType(ffiConsent: .full)
        XCTAssertEqual(consentType, .full)
    }
    
    func testInitFromFfiConsentLimited() {
        let consentType = PhoneBookConsentType(ffiConsent: .limited)
        XCTAssertEqual(consentType, .limited)
    }
    
    func testInitFromFfiConsentNone() {
        let consentType = PhoneBookConsentType(ffiConsent: FfiPhoneBookConsent.none)
        XCTAssertEqual(consentType, PhoneBookConsentType.none)
    }
    
    func testFfiConsentConversion() {
        XCTAssertEqual(PhoneBookConsentType.full.ffiConsent, .full)
        XCTAssertEqual(PhoneBookConsentType.limited.ffiConsent, .limited)
        XCTAssertEqual(PhoneBookConsentType.none.ffiConsent, .none)
    }
    
    func testFfiConsentRoundTrip() {
        for consentType in PhoneBookConsentType.allCases {
            let ffiConsent = consentType.ffiConsent
            let roundTripped = PhoneBookConsentType(ffiConsent: ffiConsent)
            XCTAssertEqual(roundTripped, consentType, "Round-trip conversion failed for \(consentType)")
        }
    }
    
    // MARK: - Codable Tests
    
    func testEncodingDecoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for consentType in PhoneBookConsentType.allCases {
            let data = try encoder.encode(consentType)
            let decoded = try decoder.decode(PhoneBookConsentType.self, from: data)
            XCTAssertEqual(decoded, consentType, "Encoding/decoding failed for \(consentType)")
        }
    }
}
