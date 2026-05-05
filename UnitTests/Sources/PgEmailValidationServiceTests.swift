//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import XCTest

final class PgEmailValidationServiceTests: XCTestCase {
    // MARK: - URL Protocol Stub
    
    private class StubURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (Int, Data))?
        
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        
        override func startLoading() {
            guard let handler = StubURLProtocol.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            do {
                let (status, data) = try handler(request)
                let response = HTTPURLResponse(url: request.url!,
                                               statusCode: status,
                                               httpVersion: nil,
                                               headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        
        override func stopLoading() { }
    }
    
    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    private func makeService(baseURL: String = "https://service.test") -> PgEmailValidationService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return PgEmailValidationService(pgServiceUrl: baseURL, session: session)
    }
    
    private func jsonData(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()
    }
    
    // MARK: - Tests
    
    func testSuccess200() async {
        let service = makeService()
        let body = jsonData(["url": "https://matrix.org"])
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        let result = await service.validateEmail(email: "user@example.com")
        switch result {
        case .success(let response):
            XCTAssertEqual(response.url, "https://matrix.org")
        case .failure(let error):
            XCTFail("Expected success, got failure \(error)")
        }
    }
    
    func testSuccess200DecodingFailure() async {
        let service = makeService()
        // Missing required "url" key -> decoding thrown -> caught by outer do/catch -> .requestFailed
        let body = jsonData(["unexpected": "value"])
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        let result = await service.validateEmail(email: "user@example.com")
        switch result {
        case .failure(let error):
            if case .requestFailed = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected requestFailed, got \(error)")
            }
        case .success:
            XCTFail("Expected failure due to decoding error")
        }
    }
    
    func testForbiddenUnknownEmailDomain403() async {
        let service = makeService()
        let body = jsonData(["title": "Err:Homeserver:UnknownEmailDomain"])
        StubURLProtocol.requestHandler = { _ in (403, body) }
        
        let result = await service.validateEmail(email: "user@unknown.com")
        switch result {
        case .failure(let error):
            if case .unknownEmailDomainError = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected unknownEmailDomainError, got \(error)")
            }
        case .success:
            XCTFail("Expected failure")
        }
    }
    
    func testForbiddenOtherError403() async {
        let service = makeService()
        let body = jsonData(["title": "SomeOtherError"])
        StubURLProtocol.requestHandler = { _ in (403, body) }
        
        let result = await service.validateEmail(email: "user@other.com")
        switch result {
        case .failure(let error):
            if case .invalidResponse = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected invalidResponse, got \(error)")
            }
        case .success:
            XCTFail("Expected failure")
        }
    }
    
    func testForbiddenMalformedBody403() async {
        let service = makeService()
        let body = Data("not json".utf8)
        StubURLProtocol.requestHandler = { _ in (403, body) }
        
        let result = await service.validateEmail(email: "user@bad.com")
        switch result {
        case .failure(let error):
            if case .decodingFailed = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected decodingFailed, got \(error)")
            }
        case .success:
            XCTFail("Expected failure")
        }
    }
    
    func testNonHandledStatus500() async {
        let service = makeService()
        StubURLProtocol.requestHandler = { _ in (500, Data()) }
        
        let result = await service.validateEmail(email: "user@server.com")
        switch result {
        case .failure(let error):
            if case .invalidResponse = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected invalidResponse, got \(error)")
            }
        case .success:
            XCTFail("Expected failure")
        }
    }
    
    func testNetworkError() async {
        let service = makeService()
        StubURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }
        
        let result = await service.validateEmail(email: "timeout@example.com")
        switch result {
        case .failure(let error):
            if case .requestFailed = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected requestFailed, got \(error)")
            }
        case .success:
            XCTFail("Expected failure")
        }
    }
    
    func testInvalidBaseURL() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = PgEmailValidationService(pgServiceUrl: "https://exa mple.com", session: session)
        
        let result = await service.validateEmail(email: "user@example.com")
        switch result {
        case .failure(let error):
            if case .invalidUrl = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected invalidUrl, got \(error)")
            }
        case .success:
            XCTFail("Expected failure")
        }
    }
}
