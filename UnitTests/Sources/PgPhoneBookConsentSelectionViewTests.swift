//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import SwiftUI
import XCTest

class PhoneBookConsentSelectionViewTests: XCTestCase {
    // MARK: - Initialization Tests
    
    func testInitializationWithFullSelection() {
        var selectedType: PhoneBookConsentType = .full
        let binding = Binding(get: { selectedType },
                              set: { selectedType = $0 })
        
        _ = PhoneBookConsentSelectionView(selectedType: binding)
        
        // The binding should still be .full (view initializes localSelection from binding)
        XCTAssertEqual(selectedType, .full)
    }
    
    func testInitializationWithLimitedSelection() {
        var selectedType: PhoneBookConsentType = .limited
        let binding = Binding(get: { selectedType },
                              set: { selectedType = $0 })
        
        _ = PhoneBookConsentSelectionView(selectedType: binding)
        
        XCTAssertEqual(selectedType, .limited)
    }
    
    func testInitializationWithNoneSelection() {
        var selectedType: PhoneBookConsentType = .none
        let binding = Binding(get: { selectedType },
                              set: { selectedType = $0 })
        
        _ = PhoneBookConsentSelectionView(selectedType: binding)
        
        XCTAssertEqual(selectedType, .none)
    }
    
    // MARK: - PhoneBookConsentType Display Properties Tests
    
    func testAllConsentTypesHaveTitles() {
        for consentType in PhoneBookConsentType.allCases {
            XCTAssertFalse(consentType.title.isEmpty, "\(consentType) should have a non-empty title")
        }
    }
    
    func testAllConsentTypesHaveSubtitles() {
        for consentType in PhoneBookConsentType.allCases {
            XCTAssertFalse(consentType.subtitle.isEmpty, "\(consentType) should have a non-empty subtitle")
        }
    }
    
    func testAllConsentTypesHaveBulletPoints() {
        for consentType in PhoneBookConsentType.allCases {
            XCTAssertFalse(consentType.bulletPoints.isEmpty, "\(consentType) should have bullet points")
            XCTAssertGreaterThanOrEqual(consentType.bulletPoints.count, 2, "\(consentType) should have at least 2 bullet points")
        }
    }
    
    func testFullConsentTypeHasNoWarning() {
        XCTAssertNil(PhoneBookConsentType.full.warningText)
    }
    
    func testLimitedConsentTypeHasWarning() throws {
        XCTAssertNotNil(PhoneBookConsentType.limited.warningText)
        XCTAssertFalse(try XCTUnwrap(PhoneBookConsentType.limited.warningText?.isEmpty))
    }
    
    func testNoneConsentTypeHasWarning() throws {
        XCTAssertNotNil(PhoneBookConsentType.none.warningText)
        XCTAssertFalse(try XCTUnwrap(PhoneBookConsentType.none.warningText?.isEmpty))
    }
    
    // MARK: - Consent Type Order Tests
    
    func testConsentTypesAreInExpectedOrder() {
        let allCases = PhoneBookConsentType.allCases
        
        // Verify the order is: full, limited, none (from most to least visible)
        XCTAssertEqual(allCases.count, 3)
        XCTAssertEqual(allCases[0], .full)
        XCTAssertEqual(allCases[1], .limited)
        XCTAssertEqual(allCases[2], .none)
    }
    
    // MARK: - Default Value Tests
    
    func testDefaultConsentTypeIsFull() {
        XCTAssertEqual(PhoneBookConsentType.default, .full)
    }
    
    // MARK: - Binding Behavior Tests
    
    func testBindingIsNotModifiedOnInitialization() {
        var callCount = 0
        var selectedType: PhoneBookConsentType = .full
        let binding = Binding(get: { selectedType },
                              set: { newValue in
                                  callCount += 1
                                  selectedType = newValue
                              })
        
        _ = PhoneBookConsentSelectionView(selectedType: binding)
        
        // The binding setter should not be called during initialization
        // (localSelection is initialized separately)
        XCTAssertEqual(callCount, 0)
    }
}
