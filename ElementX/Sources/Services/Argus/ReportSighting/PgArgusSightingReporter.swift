//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct PgArgusSightingReporter {
    private let clientProxy: ClientProxyProtocol

    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
    }

    func handleMessage(_ message: [String: Any?], envelope: PgArgusBridgeEnvelope) async -> PgArgusBridgeResponse {
        do {
            guard let payloadString = message["payload"] as? String else {
                throw PgArgusBridgeError.missingPayload
            }

            let payload = try JSONDecoder().decode(PgArgusReportSightingPayload.self,
                                                   from: Data(payloadString.utf8))
            try await clientProxy.reportSighting(payload.matrixRustValue()).get()
            MXLog.info("Argus reportSighting succeeded")
            return PgArgusBridgeResponse(type: PgArgusFeature.reportSighting.responseType,
                                         requestID: envelope.requestID)
        } catch {
            MXLog.error("Argus reportSighting failed: \(error)")
            return envelope.errorResponse(error.localizedDescription)
        }
    }
}
