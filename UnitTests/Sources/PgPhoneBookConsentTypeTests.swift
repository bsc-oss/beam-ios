//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import MatrixRustSDK
import Testing

struct PhoneBookConsentTypeTests {
    // MARK: - Raw Value Tests
    
    @Test
    func rawValues() {
        #expect(PhoneBookConsentType.full.rawValue == "full")
        #expect(PhoneBookConsentType.limited.rawValue == "limited")
        #expect(PhoneBookConsentType.none.rawValue == "none")
    }
    
    @Test
    func initFromRawValue() {
        #expect(PhoneBookConsentType(rawValue: "full") == .full)
        #expect(PhoneBookConsentType(rawValue: "limited") == .limited)
        #expect(PhoneBookConsentType(rawValue: "none") == PhoneBookConsentType.none)
        #expect(PhoneBookConsentType(rawValue: "invalid") == nil)
    }
    
    // MARK: - Default Value Test
    
    @Test
    func defaultValue() {
        #expect(PhoneBookConsentType.default == .full)
    }
    
    // MARK: - CaseIterable Tests
    
    @Test
    func allCases() {
        #expect(PhoneBookConsentType.allCases.count == 3)
        #expect(PhoneBookConsentType.allCases.contains(.full))
        #expect(PhoneBookConsentType.allCases.contains(.limited))
        #expect(PhoneBookConsentType.allCases.contains(.none))
    }
    
    // MARK: - Localized Content Tests
    
    @Test
    func titlesAreNotEmpty() {
        for consentType in PhoneBookConsentType.allCases {
            #expect(!consentType.title.isEmpty, "\(consentType) title should not be empty")
        }
    }
    
    @Test
    func subtitlesAreNotEmpty() {
        for consentType in PhoneBookConsentType.allCases {
            #expect(!consentType.subtitle.isEmpty, "\(consentType) subtitle should not be empty")
        }
    }
    
    @Test
    func bulletPointsAreNotEmpty() {
        for consentType in PhoneBookConsentType.allCases {
            #expect(!consentType.bulletPoints.isEmpty, "\(consentType) should have bullet points")
            for bullet in consentType.bulletPoints {
                #expect(!bullet.isEmpty, "\(consentType) bullet point should not be empty")
            }
        }
    }
    
    // MARK: - Warning Text Tests
    
    @Test
    func warningTextForFullIsNil() {
        #expect(PhoneBookConsentType.full.warningText == nil)
    }
    
    @Test
    func warningTextForLimitedIsNotNil() throws {
        #expect(try #require(PhoneBookConsentType.limited.warningText?.isEmpty) == false)
    }
    
    @Test
    func warningTextForNoneIsNotNil() throws {
        #expect(try #require(PhoneBookConsentType.none.warningText?.isEmpty) == false)
    }
    
    // MARK: - FFI Conversion Tests
    
    @Test
    func initFromFfiConsentFull() {
        let consentType = PhoneBookConsentType(ffiConsent: .full)
        #expect(consentType == .full)
    }
    
    @Test
    func initFromFfiConsentLimited() {
        let consentType = PhoneBookConsentType(ffiConsent: .limited)
        #expect(consentType == .limited)
    }
    
    @Test
    func initFromFfiConsentNone() {
        let consentType = PhoneBookConsentType(ffiConsent: FfiPhoneBookConsent.none)
        #expect(consentType == PhoneBookConsentType.none)
    }
    
    @Test
    func ffiConsentConversion() {
        #expect(PhoneBookConsentType.full.ffiConsent == .full)
        #expect(PhoneBookConsentType.limited.ffiConsent == .limited)
        #expect(PhoneBookConsentType.none.ffiConsent == .none)
    }
    
    @Test
    func ffiConsentRoundTrip() {
        for consentType in PhoneBookConsentType.allCases {
            let ffiConsent = consentType.ffiConsent
            let roundTripped = PhoneBookConsentType(ffiConsent: ffiConsent)
            #expect(roundTripped == consentType, "Round-trip conversion failed for \(consentType)")
        }
    }
    
    // MARK: - Codable Tests
    
    @Test
    func encodingDecoding() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for consentType in PhoneBookConsentType.allCases {
            let data = try encoder.encode(consentType)
            let decoded = try decoder.decode(PhoneBookConsentType.self, from: data)
            #expect(decoded == consentType, "Encoding/decoding failed for \(consentType)")
        }
    }
}
