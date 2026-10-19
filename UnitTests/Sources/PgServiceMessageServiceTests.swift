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

final class PgServiceMessageServiceTests {
    init() {
        StubURLProtocol.requestHandler = nil
        StubURLProtocol.resetRequestCount()
    }
    
    deinit {
        StubURLProtocol.requestHandler = nil
    }
    
    // MARK: - Helpers
    
    private func makeService(baseURL: String = "https://service.test",
                             locale: Locale = Locale(identifier: "en")) -> (PgServiceMessageService, AppSettings) {
        let appSettings = AppSettings.volatile()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = PgServiceMessageService(pgNoticeUrl: baseURL,
                                              appSettings: appSettings,
                                              session: session,
                                              localeProvider: { locale })
        return (service, appSettings)
    }
    
    private func messageJSON(id: Int = 1,
                             isActive: Bool = true,
                             isCritical: Bool = false,
                             allowDismiss: Bool = true,
                             title: String? = "Title",
                             body: String = "Body text.",
                             langCode: String = "en") -> Data {
        var contentEntry: [String: Any] = ["body": body]
        if let title {
            contentEntry["title"] = title
        }
        let payload: [String: Any] = [
            "id": id,
            "isActive": isActive,
            "isCritical": isCritical,
            "allowDismiss": allowDismiss,
            "content": [langCode: contentEntry]
        ]
        return (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
    }
    
    // MARK: - Decoding
    
    @Test
    func decodesServerPayloadUsingMessageField() throws {
        let data = Data("""
        {
          "isActive": true,
          "isCritical": true,
          "allowDismiss": false,
          "allowPersistentDismissalWeb": true,
          "id": 32,
          "content": {
            "en": {
              "title": "Scheduled Maintenance",
              "message": "Scheduled maintenance will take place tomorrow at 12:00."
            }
          }
        }
        """.utf8)
        
        let message = try JSONDecoder().decode(PgServiceMessage.self, from: data)
        
        #expect(message.id == 32)
        #expect(message.content["en"]?.title == "Scheduled Maintenance")
        #expect(message.content["en"]?.body == "Scheduled maintenance will take place tomorrow at 12:00.")
    }
    
    // MARK: - HTTP Response Handling
    
    @Test
    func refresh200PublishesActiveMessage() async {
        let (service, _) = makeService()
        let body = messageJSON(id: 7, isCritical: false, allowDismiss: true)
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        let msg = service.currentMessagePublisher.value
        #expect(msg?.id == 7)
        #expect(msg?.body == "Body text.")
        #expect(msg?.isCritical == false)
        #expect(msg?.allowDismiss == true)
    }
    
    @Test
    func refresh200InactiveMessagePublishesNil() async {
        let (service, _) = makeService()
        let body = messageJSON(isActive: false)
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    @Test
    func refresh204PublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (204, Data()) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    @Test
    func refresh404PublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (404, Data()) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    @Test
    func refreshUnexpectedStatusPublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (500, Data()) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    @Test
    func refreshNetworkErrorPublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    @Test
    func refreshInvalidBaseURLPublishesNil() async {
        let (service, _) = makeService(baseURL: "not a valid url %%")
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    @Test
    func criticalAndAllowDismissFlagsArePropagated() async {
        let (service, _) = makeService()
        let body = messageJSON(isCritical: true, allowDismiss: false)
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value?.isCritical == true)
        #expect(service.currentMessagePublisher.value?.allowDismiss == false)
    }
    
    // MARK: - Throttling
    
    @Test
    func refreshIsThrottledWithinWindow() async {
        let (service, _) = makeService()
        let body = messageJSON()
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        await service.refresh()
        
        #expect(StubURLProtocol.requestCount == 1)
    }
    
    // MARK: - Dismiss
    
    @Test
    func dismissHidesCurrentMessage() async {
        let (service, _) = makeService()
        let body = messageJSON(id: 5)
        StubURLProtocol.requestHandler = { _ in (200, body) }
        await service.refresh()
        #expect(service.currentMessagePublisher.value != nil)
        
        service.dismiss(messageID: 5)
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    @Test
    func dismissDoesNotReduceHigherStoredID() {
        let (service, appSettings) = makeService()
        appSettings.pgDismissedServiceMessageID = 10
        
        service.dismiss(messageID: 5)
        
        #expect(appSettings.pgDismissedServiceMessageID == 10)
    }
    
    @Test
    func messageWithIDHigherThanDismissedIDIsVisible() async {
        let (service, appSettings) = makeService()
        appSettings.pgDismissedServiceMessageID = 3
        let body = messageJSON(id: 4)
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value != nil)
    }
    
    @Test
    func messageWithIDEqualToDismissedIDIsHidden() async {
        let (service, appSettings) = makeService()
        appSettings.pgDismissedServiceMessageID = 4
        let body = messageJSON(id: 4)
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value == nil)
    }
    
    // MARK: - Language Resolution
    
    @Test
    func preferredLanguageContentIsSelected() async {
        let (service, _) = makeService(locale: Locale(identifier: "nl"))
        let payload: [String: Any] = [
            "id": 1, "isActive": true, "isCritical": false, "allowDismiss": true,
            "content": [
                "en": ["body": "English body"],
                "nl": ["body": "Dutch body"]
            ]
        ]
        let body = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value?.body == "Dutch body")
    }
    
    @Test
    func fallsBackToEnglishWhenPreferredLanguageUnavailable() async {
        let (service, _) = makeService(locale: Locale(identifier: "de"))
        let payload: [String: Any] = [
            "id": 1, "isActive": true, "isCritical": false, "allowDismiss": true,
            "content": [
                "en": ["body": "English body"],
                "nl": ["body": "Dutch body"]
            ]
        ]
        let body = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value?.body == "English body")
    }
    
    @Test
    func fallsBackToFirstAlphabeticallyWhenEnglishUnavailable() async {
        let (service, _) = makeService(locale: Locale(identifier: "de"))
        let payload: [String: Any] = [
            "id": 1, "isActive": true, "isCritical": false, "allowDismiss": true,
            "content": [
                "nl": ["body": "Dutch body"],
                "fr": ["body": "French body"]
            ]
        ]
        let body = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value?.body == "French body")
    }
    
    // MARK: - Title Trimming
    
    @Test
    func whitespaceOnlyTitleBecomesNil() async {
        let (service, _) = makeService()
        let body = messageJSON(title: "   ")
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value?.title == nil)
        #expect(service.currentMessagePublisher.value?.body == "Body text.")
    }
    
    @Test
    func nilTitleRemainsNil() async {
        let (service, _) = makeService()
        let body = messageJSON(title: nil)
        StubURLProtocol.requestHandler = { _ in (200, body) }
        
        await service.refresh()
        
        #expect(service.currentMessagePublisher.value?.title == nil)
    }
}

// MARK: - URL Protocol Stub

private nonisolated class StubURLProtocol: URLProtocol {
    /// URLSession drives the protocol from its own queue, so the mutable state lives behind locks.
    private static let handler: Mutex<(@Sendable (URLRequest) throws -> (Int, Data))?> = .init(nil)
    static var requestHandler: (@Sendable (URLRequest) throws -> (Int, Data))? {
        get { handler.withLock { $0 } }
        set { handler.withLock { $0 = newValue } }
    }
    
    private static let count = Mutex(0)
    static var requestCount: Int {
        count.withLock { $0 }
    }
    
    static func resetRequestCount() {
        count.withLock { $0 = 0 }
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        StubURLProtocol.count.withLock { $0 += 1 }
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
