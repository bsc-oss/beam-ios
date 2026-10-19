//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Synchronization
import Testing

final class PgEmailValidationServiceTests {
    deinit {
        StubURLProtocol.requestHandler = nil
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
    
    @Test
    func success200() async {
        let service = makeService()
        let body = jsonData(["url": "https://matrix.org"])
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        let result = await service.validateEmail(email: "user@example.com")
        switch result {
        case .success(let response):
            #expect(response.url == "https://matrix.org")
        case .failure(let error):
            Issue.record("Expected success, got failure \(error)")
        }
    }
    
    @Test
    func success200DecodingFailure() async {
        let service = makeService()
        // Missing required "url" key -> decoding thrown -> caught by outer do/catch -> .requestFailed
        let body = jsonData(["unexpected": "value"])
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        let result = await service.validateEmail(email: "user@example.com")
        switch result {
        case .failure(let error):
            guard case .requestFailed = error else {
                Issue.record("Expected requestFailed, got \(error)")
                return
            }
        case .success:
            Issue.record("Expected failure due to decoding error")
        }
    }
    
    @Test
    func forbiddenUnknownEmailDomain403() async {
        let service = makeService()
        let body = jsonData(["title": "Err:Homeserver:UnknownEmailDomain"])
        StubURLProtocol.requestHandler = { _ in (403, body) }
        
        let result = await service.validateEmail(email: "user@unknown.com")
        switch result {
        case .failure(let error):
            guard case .unknownEmailDomainError = error else {
                Issue.record("Expected unknownEmailDomainError, got \(error)")
                return
            }
        case .success:
            Issue.record("Expected failure")
        }
    }
    
    @Test
    func forbiddenOtherError403() async {
        let service = makeService()
        let body = jsonData(["title": "SomeOtherError"])
        StubURLProtocol.requestHandler = { _ in (403, body) }
        
        let result = await service.validateEmail(email: "user@other.com")
        switch result {
        case .failure(let error):
            guard case .invalidResponse = error else {
                Issue.record("Expected invalidResponse, got \(error)")
                return
            }
        case .success:
            Issue.record("Expected failure")
        }
    }
    
    @Test
    func forbiddenMalformedBody403() async {
        let service = makeService()
        let body = Data("not json".utf8)
        StubURLProtocol.requestHandler = { _ in (403, body) }
        
        let result = await service.validateEmail(email: "user@bad.com")
        switch result {
        case .failure(let error):
            guard case .decodingFailed = error else {
                Issue.record("Expected decodingFailed, got \(error)")
                return
            }
        case .success:
            Issue.record("Expected failure")
        }
    }
    
    @Test
    func nonHandledStatus500() async {
        let service = makeService()
        StubURLProtocol.requestHandler = { _ in (500, Data()) }
        
        let result = await service.validateEmail(email: "user@server.com")
        switch result {
        case .failure(let error):
            guard case .invalidResponse = error else {
                Issue.record("Expected invalidResponse, got \(error)")
                return
            }
        case .success:
            Issue.record("Expected failure")
        }
    }
    
    @Test
    func networkError() async {
        let service = makeService()
        StubURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }
        
        let result = await service.validateEmail(email: "timeout@example.com")
        switch result {
        case .failure(let error):
            guard case .requestFailed = error else {
                Issue.record("Expected requestFailed, got \(error)")
                return
            }
        case .success:
            Issue.record("Expected failure")
        }
    }
    
    @Test
    func invalidBaseURL() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = PgEmailValidationService(pgServiceUrl: "https://exa mple.com", session: session)
        
        let result = await service.validateEmail(email: "user@example.com")
        switch result {
        case .failure(let error):
            guard case .invalidUrl = error else {
                Issue.record("Expected invalidUrl, got \(error)")
                return
            }
        case .success:
            Issue.record("Expected failure")
        }
    }
}

// MARK: - URL Protocol Stub

private nonisolated class StubURLProtocol: URLProtocol {
    /// URLSession drives the protocol from its own queue, so the handler lives behind a lock.
    private static let handler: Mutex<(@Sendable (URLRequest) throws -> (Int, Data))?> = .init(nil)
    static var requestHandler: (@Sendable (URLRequest) throws -> (Int, Data))? {
        get { handler.withLock { $0 } }
        set { handler.withLock { $0 = newValue } }
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
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
