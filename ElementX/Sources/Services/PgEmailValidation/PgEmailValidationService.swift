//
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

class PgEmailValidationService: NSObject, PgEmailValidationServiceProtocol {
    private let pgServiceUrl: String
    private let session: URLSession
        
    init(pgServiceUrl: String,
         session: URLSession = .shared) {
        self.pgServiceUrl = pgServiceUrl
        self.session = session
        
        super.init()
    }

    func validateEmail(email: String) async -> Result<PgEmailValidationResponse, PgEmailValidationError> {
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        guard let encodedEmail else { return .failure(.invalidEmail) }
        
        let pgServiceFindByEmailUrl = "\(pgServiceUrl)/homeserver/find-by-email?email=\(encodedEmail)"
        
        guard let pgServiceUrl = URL(string: pgServiceFindByEmailUrl) else {
            return .failure(.invalidUrl(url: pgServiceUrl))
        }
        
        let request = URLRequest(url: pgServiceUrl)
        
        do {
            let (data, response) = try await session.dataWithRetry(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            switch httpResponse.statusCode {
            case 200:
                let successResponse = try JSONDecoder().decode(PgEmailValidationResponse.self, from: data)
                return .success(successResponse)
            case 403:
                do {
                    let errorResponse = try JSONDecoder().decode(PgEmailValidationErrorResponse.self, from: data)
                    let isUnknownEmailDomainError = errorResponse.title == "Err:Homeserver:UnknownEmailDomain"
                    
                    return .failure(isUnknownEmailDomainError ? .unknownEmailDomainError : .invalidResponse)
                } catch {
                    return .failure(.decodingFailed(error: error))
                }
            default:
                return .failure(.invalidResponse)
            }
        } catch {
            return .failure(.requestFailed(error: error))
        }
    }
}

// MARK: - Mocks

extension PgEmailValidationService {
    static var mock: PgEmailValidationService {
        PgEmailValidationService(pgServiceUrl: "https://serv.devserver3.local", session: .shared)
    }
}
