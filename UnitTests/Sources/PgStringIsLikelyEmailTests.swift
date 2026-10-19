//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Testing

struct PgStringIsLikelyEmailTests {
    // MARK: - Step 0: trimming
    
    @Test
    func step0TrimmingValidation() {
        #expect(" firstname.lastname@example.com".isLikelyEmail, "Email should be valid given it has leading space")
        #expect("firstname.lastname@example.com ".isLikelyEmail, "Email should be valid given it has trailing space")
        #expect("   firstname.lastname@example.com    ".isLikelyEmail, "Email should be valid given it has leading/trailing spaces")
        
        #expect(!"\t \n".isLikelyEmail, "Email should be invalid given it has only space and newline")
    }
    
    // MARK: - Step 1: Total length validation (≤ 254 characters)
    
    @Test
    func step1TotalLengthValidation() {
        // Valid: exactly at limit
        let valid254 = String(repeating: "a", count: 64) + "@" + String(repeating: "b", count: 63) + "." + String(repeating: "c", count: 63) + "." + String(repeating: "d", count: 57) + ".com" // 254 chars total
        #expect(valid254.count == 254, "Email with exactly 254 characters should have exactly 254 characters")
        #expect(valid254.isLikelyEmail, "Email with exactly 254 characters should be valid")
        
        // Invalid: exceeds limit
        let invalid255 = String(repeating: "a", count: 244) + "@domain.com" // 255 chars total
        #expect(invalid255.count == 255, "Email with exactly 255 characters should have exactly 255 characters")
        #expect(!invalid255.isLikelyEmail, "Email with 255 characters should be invalid")
        
        // Valid: well under limit
        #expect("test@example.com".isLikelyEmail, "Short email should be valid")
        
        // Valid: empty local part but within length
        #expect(!"@domain.com".isLikelyEmail, "Empty local part should be invalid")
    }
    
    // MARK: - Step 2: Split on single '@' validation
    
    @Test
    func step2SingleAtSymbolValidation() {
        // Valid: single @ symbol
        #expect("user@domain.com".isLikelyEmail, "Email with single @ should be valid")
        
        // Invalid: no @ symbol
        #expect(!"userdomain.com".isLikelyEmail, "Email without @ should be invalid")
        
        // Invalid: multiple @ symbols
        #expect(!"user@domain@com".isLikelyEmail, "Email with multiple @ should be invalid")
        #expect(!"user@@domain.com".isLikelyEmail, "Email with consecutive @ should be invalid")
        
        // Invalid: @ at start
        #expect(!"@domain.com".isLikelyEmail, "Email starting with @ should be invalid")
        
        // Invalid: @ at end
        #expect(!"user@".isLikelyEmail, "Email ending with @ should be invalid")
        
        // Invalid: only @ symbol
        #expect(!"@".isLikelyEmail, "Single @ symbol should be invalid")
    }
    
    // MARK: - Step 3: Local part length validation (1-64 characters)
    
    @Test
    func step3LocalPartLengthValidation() {
        // Valid: minimum length (1 character)
        #expect("a@domain.com".isLikelyEmail, "Email with 1-char local part should be valid")
        
        // Valid: maximum length (64 characters)
        let valid64Local = String(repeating: "a", count: 64) + "@domain.com"
        #expect(valid64Local.isLikelyEmail, "Email with 64-char local part should be valid")
        
        // Invalid: exceeds maximum (65 characters)
        let invalid65Local = String(repeating: "a", count: 65) + "@domain.com"
        #expect(!invalid65Local.isLikelyEmail, "Email with 65-char local part should be invalid")
        
        // Valid: common lengths
        #expect("user@domain.com".isLikelyEmail, "Email with 4-char local part should be valid")
        #expect("testuser@domain.com".isLikelyEmail, "Email with 8-char local part should be valid")
        
        // Edge case: exactly at boundaries
        let valid63Local = String(repeating: "a", count: 63) + "@domain.com"
        #expect(valid63Local.isLikelyEmail, "Email with 63-char local part should be valid")
    }
    
    // MARK: - Step 4: Domain length validation (≤ 253 characters)
    
    @Test
    func step4DomainLengthValidation() {
        // Valid: maximum domain length (253 characters) - max testable is 252 chars domain because of total length being 254.
        let longDomain = String(repeating: "a", count: 63) + "." + String(repeating: "b", count: 63) + "." + String(repeating: "c", count: 63) + "." + String(repeating: "d", count: 56) + ".com" // 252 chars total
        let valid252Domain = "a@" + longDomain
        #expect(valid252Domain.count == 254, "Email with exactly 254 characters should have exactly 254 characters")
        #expect(valid252Domain.isLikelyEmail, "Email with 252-char domain should be valid")
        
        // Invalid: exceeds maximum (254 characters)
        let tooLongDomain = String(repeating: "a", count: 250) + ".com" // 254 chars total
        let invalid254Domain = "user@" + tooLongDomain
        #expect(!invalid254Domain.isLikelyEmail, "Email with 254-char domain should be invalid")
        
        // Valid: short domain
        #expect("user@a.co".isLikelyEmail, "Email with short domain should be valid")
        
        // Valid: common domain lengths
        #expect("user@example.com".isLikelyEmail, "Email with common domain should be valid")
        #expect("user@subdomain.example.com".isLikelyEmail, "Email with subdomain should be valid")
    }
    
    // MARK: - Step 5: Domain labels validation (1-63 characters per label)
    
    @Test
    func step5DomainLabelsValidation() {
        // Valid: single label domains
        #expect("user@domain.com".isLikelyEmail, "Email with normal labels should be valid")
        
        // Valid: multiple labels
        #expect("user@sub.domain.com".isLikelyEmail, "Email with subdomains should be valid")
        #expect("user@a.b.c.d.com".isLikelyEmail, "Email with multiple subdomains should be valid")
        
        // Valid: maximum label length (63 characters)
        let maxLabel = String(repeating: "a", count: 63)
        let validMaxLabel = "user@" + maxLabel + ".com"
        #expect(validMaxLabel.isLikelyEmail, "Email with 63-char label should be valid")
        
        // Invalid: label exceeds maximum (64 characters)
        let tooLongLabel = String(repeating: "a", count: 64)
        let invalidLongLabel = "user@" + tooLongLabel + ".com"
        #expect(!invalidLongLabel.isLikelyEmail, "Email with 64-char label should be invalid")
        
        // Invalid: empty domain (no labels)
        // This is handled by the "no @ at end" check in step 2, but testing here too
        #expect(!"user@".isLikelyEmail, "Email without domain should be invalid")
        
        // Valid: minimum label length (1 character)
        #expect("user@a.be".isLikelyEmail, "Email with 1-char labels should be valid")
        
        // Test multiple labels with various lengths
        let mixedLabels = "user@" + String(repeating: "a", count: 10) + "." + String(repeating: "b", count: 20) + ".com"
        #expect(mixedLabels.isLikelyEmail, "Email with mixed label lengths should be valid")
    }
    
    // MARK: - Step 6: TLD heuristic validation (2-24 characters)
    
    @Test
    func step6TLDHeuristicValidation() {
        // Valid: minimum TLD length (2 characters)
        #expect("user@domain.co".isLikelyEmail, "Email with 2-char TLD should be valid")
        
        // Valid: maximum TLD length (24 characters)
        let maxTLD = String(repeating: "a", count: 24)
        let validMaxTLD = "user@domain." + maxTLD
        #expect(validMaxTLD.isLikelyEmail, "Email with 24-char TLD should be valid")
        
        // Invalid: TLD too short (1 character)
        #expect(!"user@domain.a".isLikelyEmail, "Email with 1-char TLD should be invalid")
        
        // Invalid: TLD too long (25 characters)
        let tooLongTLD = String(repeating: "a", count: 25)
        let invalidLongTLD = "user@domain." + tooLongTLD
        #expect(!invalidLongTLD.isLikelyEmail, "Email with 25-char TLD should be invalid")
        
        // Valid: common TLD lengths
        #expect("user@domain.be".isLikelyEmail, "Email with be TLD should be valid")
        #expect("user@domain.com".isLikelyEmail, "Email with com TLD should be valid")
        
        // Edge cases: exactly at boundaries
        let valid23TLD = String(repeating: "a", count: 23)
        let valid23 = "user@domain." + valid23TLD
        #expect(valid23.isLikelyEmail, "Email with 23-char TLD should be valid")
        
        let valid3TLD = "abc"
        let valid3 = "user@domain." + valid3TLD
        #expect(valid3.isLikelyEmail, "Email with 3-char TLD should be valid")
    }
    
    // MARK: - Step 7: Structural pattern validation (regex)
    
    @Test
    func step7StructuralPatternValidation() {
        // Valid: basic alphanumeric
        #expect("user@domain.com".isLikelyEmail, "Basic alphanumeric email should be valid")
        
        // Valid: allowed special characters in local part
        #expect("user.name@domain.com".isLikelyEmail, "Email with dot in local should be valid")
        #expect("user_underscore@domain.com".isLikelyEmail, "Email with underscore should be valid")
        #expect("user%percent@domain.com".isLikelyEmail, "Email with percent should be valid")
        #expect("user+plus@domain.com".isLikelyEmail, "Email with plus should be valid")
        #expect("user-dash@domain.com".isLikelyEmail, "Email with dash in local should be valid")
        #expect("123@domain.com".isLikelyEmail, "Email with numbers in local should be valid")
        
        // Valid: allowed characters in domain
        #expect("user@sub-domain.com".isLikelyEmail, "Email with dash in domain should be valid")
        #expect("user@123domain.com".isLikelyEmail, "Email with numbers in domain should be valid")
        #expect("user@DOMAIN.COM".isLikelyEmail, "Email with uppercase domain should be valid")
        
        // Valid: case insensitive
        #expect("USER@DOMAIN.COM".isLikelyEmail, "Uppercase email should be valid")
        #expect("User.Name@Sub-Domain.COM".isLikelyEmail, "Mixed case email should be valid")
        
        // Valid: complex but allowed patterns
        #expect("user.name+tag123@sub-domain123.example.com".isLikelyEmail, "Complex valid email should be valid")
        #expect("a1.b2_c3%d4+e5-f6@g7-h8.i9.j10.com".isLikelyEmail, "Email with all allowed chars should be valid")
        
        // Invalid: disallowed characters (these would fail the regex)
        #expect(!"user@domain..com".isLikelyEmail, "Email with consecutive dots should be invalid")
        #expect(!"user@domain.".isLikelyEmail, "Email ending with dot should be invalid")
        #expect(!"user@.domain.com".isLikelyEmail, "Email starting domain with dot should be invalid")
        
        // Invalid: email without domain label and just the TLD
        #expect(!"user@be".isLikelyEmail, "Email without domain label and just TLD should be invalid")
        
        // Valid: minimum required structure
        #expect("a@b.co".isLikelyEmail, "Minimal valid email should be valid")
        
        // Test that the regex is case insensitive
        #expect("test@EXAMPLE.COM".isLikelyEmail, "Uppercase domain should be valid")
        #expect("TEST@example.com".isLikelyEmail, "Uppercase local should be valid")
    }
    
    // MARK: - Integration tests (combining multiple steps)
    
    @Test
    func integrationValidEmails() {
        let validEmails = [
            "test@example.be",
            "user.name@domain.be",
            "user+tag@subdomain.example.be",
            "123@456.co",
            "a@b.co",
            "user_underscore@domain-with-dash.com",
            "user%percent+plus@sub.domain.travel"
        ]
        
        for email in validEmails {
            #expect(email.isLikelyEmail, "Email '\(email)' should be valid")
        }
    }
    
    @Test
    func integrationInvalidEmails() {
        let invalidEmails = [
            "", // empty
            "plainaddress", // no @
            "@missingdomain.com", // no local part
            "missing@.com", // empty domain label
            "user@", // no domain
            "user@@domain.com", // double @
            "user@domain@com", // multiple @
            "user@domain.", // no TLD
            "user@domain.c", // TLD too short
            "user@domain..com", // consecutive dots
            String(repeating: "a", count: 255) + "@domain.com", // too long overall
            "user@" + String(repeating: "a", count: 254) + ".com", // domain too long
            String(repeating: "a", count: 65) + "@domain.com", // local part too long
            "user@domain." + String(repeating: "a", count: 25), // TLD too long
            "user@" + String(repeating: "a", count: 64) + ".com" // domain label too long
        ]
        
        for email in invalidEmails {
            #expect(!email.isLikelyEmail, "Email '\(email)' should be invalid")
        }
    }
}
