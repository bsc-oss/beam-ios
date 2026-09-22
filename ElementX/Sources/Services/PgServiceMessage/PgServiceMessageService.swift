//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

final class PgServiceMessageService: PgServiceMessageServiceProtocol {
    /// Throttle window between successive network fetches.
    private static let throttleIntervalInSeconds: TimeInterval = 15 * 60
    
    private let pgNoticeUrl: String
    private let appSettings: AppSettings
    private let session: URLSession
    private let localeProvider: () -> Locale
    
    private let messageSubject: CurrentValueSubject<PgServiceMessageDisplay?, Never> = .init(nil)
    
    /// The latest decoded message from the server (regardless of dismissal). Cached so that dismissals
    /// can be re-evaluated without a network round-trip.
    private var latestMessage: PgServiceMessage?
    private var lastFetchDate: Date?
    private var inflightTask: Task<Void, Never>?
    
    var currentMessagePublisher: CurrentValuePublisher<PgServiceMessageDisplay?, Never> {
        messageSubject.asCurrentValuePublisher()
    }
    
    init(pgNoticeUrl: String,
         appSettings: AppSettings,
         session: URLSession = .shared,
         localeProvider: @escaping () -> Locale = { Locale.current }) {
        self.pgNoticeUrl = pgNoticeUrl
        self.appSettings = appSettings
        self.session = session
        self.localeProvider = localeProvider
    }
    
    func refresh() async {
        if let lastFetchDate, Date().timeIntervalSince(lastFetchDate) < Self.throttleIntervalInSeconds {
            return
        }
        
        if let inflightTask {
            await inflightTask.value
            return
        }
        
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.performFetch()
        }
        inflightTask = task
        await task.value
        inflightTask = nil
    }
    
    func dismiss(messageID: Int) {
        let current = appSettings.pgDismissedServiceMessageID ?? Int.min
        if messageID > current {
            appSettings.pgDismissedServiceMessageID = messageID
        }
        recomputeDisplayedMessage()
    }
    
    // MARK: - Private
    
    private func performFetch() async {
        defer { recomputeDisplayedMessage() }

        guard let url = URL(string: "\(pgNoticeUrl)/service-message") else {
            MXLog.error("PgServiceMessageService: invalid notice URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await session.dataWithRetry(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                latestMessage = nil
                MXLog.error("PgServiceMessageService: invalid response")
                return
            }

            lastFetchDate = Date()

            switch httpResponse.statusCode {
            case 200:
                let message = try JSONDecoder().decode(PgServiceMessage.self, from: data)
                latestMessage = message
                MXLog.info("PgServiceMessageService: fetched message id=\(message.id) active=\(message.isActive) critical=\(message.isCritical)")
            case 204, 404:
                // No message available.
                latestMessage = nil
                MXLog.info("PgServiceMessageService: no service message available (status \(httpResponse.statusCode))")
            default:
                latestMessage = nil
                MXLog.error("PgServiceMessageService: unexpected status code \(httpResponse.statusCode)")
            }
        } catch {
            latestMessage = nil
            MXLog.error("PgServiceMessageService: fetch failed: \(error.logDescription)")
        }
    }
    
    private func recomputeDisplayedMessage() {
        let displayed = displayedMessage(from: latestMessage)
        if displayed != messageSubject.value {
            messageSubject.send(displayed)
        }
    }
    
    private func displayedMessage(from message: PgServiceMessage?) -> PgServiceMessageDisplay? {
        guard let message, message.isActive else { return nil }
        
        if let dismissedID = appSettings.pgDismissedServiceMessageID, message.id <= dismissedID {
            return nil
        }
        
        guard let content = resolveContent(in: message) else { return nil }
        
        return PgServiceMessageDisplay(id: message.id,
                                       isCritical: message.isCritical,
                                       allowDismiss: message.allowDismiss,
                                       title: content.title?.trimmedNonEmpty,
                                       body: content.body)
    }
    
    private func resolveContent(in message: PgServiceMessage) -> PgServiceMessageContent? {
        let preferredLanguage = localeProvider().language.languageCode?.identifier.lowercased()
        let lowercasedContent = Dictionary(uniqueKeysWithValues: message.content.map { ($0.key.lowercased(), $0.value) })
        
        if let preferredLanguage, let match = lowercasedContent[preferredLanguage] {
            return match
        }
        if let english = lowercasedContent["en"] {
            return english
        }
        // Fall back to the first available entry, ordered by key for determinism.
        return lowercasedContent.sorted { $0.key < $1.key }.first?.value
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Error {
    var logDescription: String {
        guard let decodingError = self as? DecodingError else {
            return localizedDescription
        }

        switch decodingError {
        case .keyNotFound(let key, let context):
            return "missing key '\(key.stringValue)' at \(context.codingPath.logPath)"
        case .typeMismatch(let type, let context):
            return "type mismatch for \(type) at \(context.codingPath.logPath): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "missing value for \(type) at \(context.codingPath.logPath): \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "invalid data at \(context.codingPath.logPath): \(context.debugDescription)"
        @unknown default:
            return localizedDescription
        }
    }
}

private extension Array where Element == CodingKey {
    var logPath: String {
        map { key in
            if let intValue = key.intValue {
                return "[\(intValue)]"
            }

            return key.stringValue
        }
        .joined(separator: ".")
    }
}

// MARK: - Mocks

extension PgServiceMessageService {
    static func mock(appSettings: AppSettings) -> PgServiceMessageService {
        PgServiceMessageService(pgNoticeUrl: "https://serv.devserver3.local", appSettings: appSettings)
    }
}
