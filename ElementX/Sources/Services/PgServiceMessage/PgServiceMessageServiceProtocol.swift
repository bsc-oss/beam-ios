//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

/// A localised content entry for a service message (one per language code).
struct PgServiceMessageContent: Decodable, Equatable {
    let title: String?
    let body: String

    private enum CodingKeys: String, CodingKey {
        case title
        case body
        case message
    }

    init(title: String?, body: String) {
        self.title = title
        self.body = body
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decodeIfPresent(String.self, forKey: .title)

        if let body = try container.decodeIfPresent(String.self, forKey: .body) {
            self.body = body
        } else {
            body = try container.decode(String.self, forKey: .message)
        }
    }
}

/// The raw service message payload returned by the server.
///
/// The server can hide the banner instantly without an app release by setting `isActive: false`.
struct PgServiceMessage: Decodable, Equatable {
    let id: Int
    let isActive: Bool
    let isCritical: Bool
    let allowDismiss: Bool
    /// Map of language code (`nl`, `fr`, `de`, `en`, …) to localised content.
    let content: [String: PgServiceMessageContent]
}

/// A service message that has been resolved to the device's preferred language and is ready to be displayed.
struct PgServiceMessageDisplay: Equatable {
    let id: Int
    let isCritical: Bool
    let allowDismiss: Bool
    let title: String?
    let body: String
}

// sourcery: AutoMockable
protocol PgServiceMessageServiceProtocol: AnyObject {
    /// The current service message that should be displayed, or `nil` if no message is active or the
    /// active message has been dismissed by the user.
    var currentMessagePublisher: CurrentValuePublisher<PgServiceMessageDisplay?, Never> { get }
    
    /// Refresh the service message from the server. The implementation throttles fetches to once
    /// every 15 minutes — additional calls within the throttle window are no-ops.
    func refresh() async
    
    /// Mark a message id as dismissed. Messages with a higher id will re-appear automatically.
    func dismiss(messageID: Int)
}
