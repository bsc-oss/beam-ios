//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import PGArgusMobileBrownfield

@MainActor
final class PgArgusBridge {
    private let uploadHandler: PgArgusFileUploadHandler
    private let sightingReporter: PgArgusSightingReporter
    private var listenerID: String?

    init(clientProxy: ClientProxyProtocol) {
        uploadHandler = PgArgusFileUploadHandler(clientProxy: clientProxy)
        sightingReporter = PgArgusSightingReporter(clientProxy: clientProxy)
        registerListener()
    }

    deinit {
        if let listenerID {
            BrownfieldMessaging.removeListener(id: listenerID)
        }
    }

    private func registerListener() {
        listenerID = BrownfieldMessaging.addListener { [weak self] message in
            guard let self else { return }

            Task { @MainActor in
                await self.handleMessage(message)
            }
        }

        MXLog.info("Registered Argus bridge listener")
    }

    private func handleMessage(_ message: [String: Any?]) async {
        guard let envelope = PgArgusBridgeEnvelope(message: message),
              let response = await dispatch(envelope, message: message) else {
            return
        }

        BrownfieldMessaging.sendMessage(response.toMessage())
    }

    private func dispatch(_ envelope: PgArgusBridgeEnvelope, message: [String: Any?]) async -> PgArgusBridgeResponse? {
        switch envelope.feature {
        case .uploadFile:
            return await uploadHandler.handleMessage(message, envelope: envelope)
        case .reportSighting:
            return await sightingReporter.handleMessage(message, envelope: envelope)
        case .none:
            return nil
        }
    }
}
