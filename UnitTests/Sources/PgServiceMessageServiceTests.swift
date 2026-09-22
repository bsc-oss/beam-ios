//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import XCTest

final class PgServiceMessageServiceTests: XCTestCase {
    // MARK: - URL Protocol Stub

    private class StubURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (Int, Data))?
        static var requestCount = 0

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            StubURLProtocol.requestCount += 1
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

    override func setUp() {
        super.setUp()
        AppSettings.resetAllSettings()
        StubURLProtocol.requestHandler = nil
        StubURLProtocol.requestCount = 0
    }

    // MARK: - Helpers

    private func makeService(baseURL: String = "https://service.test",
                             locale: Locale = Locale(identifier: "en")) -> (PgServiceMessageService, AppSettings) {
        let appSettings = AppSettings()
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
        if let title { contentEntry["title"] = title }
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

    func testDecodesServerPayloadUsingMessageField() throws {
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

        XCTAssertEqual(message.id, 32)
        XCTAssertEqual(message.content["en"]?.title, "Scheduled Maintenance")
        XCTAssertEqual(message.content["en"]?.body, "Scheduled maintenance will take place tomorrow at 12:00.")
    }

    // MARK: - HTTP Response Handling

    func testRefresh200PublishesActiveMessage() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(id: 7, isCritical: false, allowDismiss: true)) }

        await service.refresh()

        let msg = service.currentMessagePublisher.value
        XCTAssertEqual(msg?.id, 7)
        XCTAssertEqual(msg?.body, "Body text.")
        XCTAssertEqual(msg?.isCritical, false)
        XCTAssertEqual(msg?.allowDismiss, true)
    }

    func testRefresh200InactiveMessagePublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(isActive: false)) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    func testRefresh204PublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (204, Data()) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    func testRefresh404PublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (404, Data()) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    func testRefreshUnexpectedStatusPublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (500, Data()) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    func testRefreshNetworkErrorPublishesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    func testRefreshInvalidBaseURLPublishesNil() async {
        let (service, _) = makeService(baseURL: "not a valid url %%")

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    func testCriticalAndAllowDismissFlagsArePropagated() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(isCritical: true, allowDismiss: false)) }

        await service.refresh()

        XCTAssertEqual(service.currentMessagePublisher.value?.isCritical, true)
        XCTAssertEqual(service.currentMessagePublisher.value?.allowDismiss, false)
    }

    // MARK: - Throttling

    func testRefreshIsThrottledWithinWindow() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON()) }

        await service.refresh()
        await service.refresh()

        XCTAssertEqual(StubURLProtocol.requestCount, 1)
    }

    // MARK: - Dismiss

    func testDismissHidesCurrentMessage() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(id: 5)) }
        await service.refresh()
        XCTAssertNotNil(service.currentMessagePublisher.value)

        service.dismiss(messageID: 5)

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    func testDismissDoesNotReduceHigherStoredID() {
        let (service, appSettings) = makeService()
        appSettings.pgDismissedServiceMessageID = 10

        service.dismiss(messageID: 5)

        XCTAssertEqual(appSettings.pgDismissedServiceMessageID, 10)
    }

    func testMessageWithIDHigherThanDismissedIDIsVisible() async {
        let (service, appSettings) = makeService()
        appSettings.pgDismissedServiceMessageID = 3
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(id: 4)) }

        await service.refresh()

        XCTAssertNotNil(service.currentMessagePublisher.value)
    }

    func testMessageWithIDEqualToDismissedIDIsHidden() async {
        let (service, appSettings) = makeService()
        appSettings.pgDismissedServiceMessageID = 4
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(id: 4)) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value)
    }

    // MARK: - Language Resolution

    func testPreferredLanguageContentIsSelected() async {
        let (service, _) = makeService(locale: Locale(identifier: "nl"))
        let payload: [String: Any] = [
            "id": 1, "isActive": true, "isCritical": false, "allowDismiss": true,
            "content": [
                "en": ["body": "English body"],
                "nl": ["body": "Dutch body"]
            ]
        ]
        StubURLProtocol.requestHandler = { _ in
            (200, (try? JSONSerialization.data(withJSONObject: payload)) ?? Data())
        }

        await service.refresh()

        XCTAssertEqual(service.currentMessagePublisher.value?.body, "Dutch body")
    }

    func testFallsBackToEnglishWhenPreferredLanguageUnavailable() async {
        let (service, _) = makeService(locale: Locale(identifier: "de"))
        let payload: [String: Any] = [
            "id": 1, "isActive": true, "isCritical": false, "allowDismiss": true,
            "content": [
                "en": ["body": "English body"],
                "nl": ["body": "Dutch body"]
            ]
        ]
        StubURLProtocol.requestHandler = { _ in
            (200, (try? JSONSerialization.data(withJSONObject: payload)) ?? Data())
        }

        await service.refresh()

        XCTAssertEqual(service.currentMessagePublisher.value?.body, "English body")
    }

    func testFallsBackToFirstAlphabeticallyWhenEnglishUnavailable() async {
        let (service, _) = makeService(locale: Locale(identifier: "de"))
        let payload: [String: Any] = [
            "id": 1, "isActive": true, "isCritical": false, "allowDismiss": true,
            "content": [
                "nl": ["body": "Dutch body"],
                "fr": ["body": "French body"]
            ]
        ]
        StubURLProtocol.requestHandler = { _ in
            (200, (try? JSONSerialization.data(withJSONObject: payload)) ?? Data())
        }

        await service.refresh()

        XCTAssertEqual(service.currentMessagePublisher.value?.body, "French body")
    }

    // MARK: - Title Trimming

    func testWhitespaceOnlyTitleBecomesNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(title: "   ")) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value?.title)
        XCTAssertEqual(service.currentMessagePublisher.value?.body, "Body text.")
    }

    func testNilTitleRemainsNil() async {
        let (service, _) = makeService()
        StubURLProtocol.requestHandler = { _ in (200, self.messageJSON(title: nil)) }

        await service.refresh()

        XCTAssertNil(service.currentMessagePublisher.value?.title)
    }
}
