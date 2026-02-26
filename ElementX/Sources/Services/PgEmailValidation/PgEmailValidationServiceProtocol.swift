//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct PgEmailValidationResponse: Decodable {
    var url: String
}

struct PgEmailValidationErrorResponse: Decodable {
    var title: String?
}

enum PgEmailValidationError: Error {
    case invalidEmail
    case invalidUrl(url: String)
    case invalidResponse
    case unknownEmailDomainError
    case requestFailed(error: Error)
    case decodingFailed(error: Error)
}

// sourcery: AutoMockable
protocol PgEmailValidationServiceProtocol: AnyObject {
    func validateEmail(email: String) async -> Result<PgEmailValidationResponse, PgEmailValidationError>
}
