//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import SwiftUI
import Testing

struct PhoneBookConsentSelectionViewTests {
    // MARK: - Initialization Tests
    
    @Test
    func initializationWithFullSelection() {
        var selectedType: PhoneBookConsentType = .full
        let binding = Binding(get: { selectedType },
                              set: { selectedType = $0 })
        
        _ = PhoneBookConsentSelectionView(selectedType: binding)
        
        // The binding should still be .full (view initializes localSelection from binding)
        #expect(selectedType == .full)
    }
    
    @Test
    func initializationWithLimitedSelection() {
        var selectedType: PhoneBookConsentType = .limited
        let binding = Binding(get: { selectedType },
                              set: { selectedType = $0 })
        
        _ = PhoneBookConsentSelectionView(selectedType: binding)
        
        #expect(selectedType == .limited)
    }
    
    @Test
    func initializationWithNoneSelection() {
        var selectedType: PhoneBookConsentType = .none
        let binding = Binding(get: { selectedType },
                              set: { selectedType = $0 })
        
        _ = PhoneBookConsentSelectionView(selectedType: binding)
        
        #expect(selectedType == .none)
    }
    
    // MARK: - PhoneBookConsentType Display Properties Tests
    
    @Test
    func allConsentTypesHaveTitles() {
        for consentType in PhoneBookConsentType.allCases {
            #expect(!consentType.title.isEmpty, "\(consentType) should have a non-empty title")
        }
    }
    
    @Test
    func allConsentTypesHaveSubtitles() {
        for consentType in PhoneBookConsentType.allCases {
            #expect(!consentType.subtitle.isEmpty, "\(consentType) should have a non-empty subtitle")
        }
    }
    
    @Test
    func allConsentTypesHaveBulletPoints() {
        for consentType in PhoneBookConsentType.allCases {
            #expect(!consentType.bulletPoints.isEmpty, "\(consentType) should have bullet points")
            #expect(consentType.bulletPoints.count >= 2, "\(consentType) should have at least 2 bullet points")
        }
    }
    
    @Test
    func fullConsentTypeHasNoWarning() {
        #expect(PhoneBookConsentType.full.warningText == nil)
    }
    
    @Test
    func limitedConsentTypeHasWarning() throws {
        #expect(try #require(PhoneBookConsentType.limited.warningText?.isEmpty) == false)
    }
    
    @Test
    func noneConsentTypeHasWarning() throws {
        #expect(try #require(PhoneBookConsentType.none.warningText?.isEmpty) == false)
    }
    
    // MARK: - Consent Type Order Tests
    
    @Test
    func consentTypesAreInExpectedOrder() {
        let allCases = PhoneBookConsentType.allCases
        
        // Verify the order is: full, limited, none (from most to least visible)
        #expect(allCases.count == 3)
        #expect(allCases[0] == .full)
        #expect(allCases[1] == .limited)
        #expect(allCases[2] == .none)
    }
    
    // MARK: - Default Value Tests
    
    @Test
    func defaultConsentTypeIsFull() {
        #expect(PhoneBookConsentType.default == .full)
    }
    
    // MARK: - Binding Behavior Tests
    
    @Test
    func bindingIsNotModifiedOnInitialization() {
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
        #expect(callCount == 0)
    }
}
