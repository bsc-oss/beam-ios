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
        // The bundle invokes this on its JavaScript thread. A main-actor closure traps there (Swift 6 checks
        // isolation when handing one to a Swift 5 module), so decode the Sendable envelope in place, then hop.
        listenerID = BrownfieldMessaging.addListener { @Sendable [weak self] message in
            guard let envelope = PgArgusBridgeEnvelope(message: message) else { return }
            
            Task { @MainActor in
                await self?.handle(envelope)
            }
        }
        
        MXLog.info("Registered Argus bridge listener")
    }
    
    private func handle(_ envelope: PgArgusBridgeEnvelope) async {
        guard let response = await dispatch(envelope) else { return }
        
        BrownfieldMessaging.sendMessage(response.toMessage())
    }
    
    private func dispatch(_ envelope: PgArgusBridgeEnvelope) async -> PgArgusBridgeResponse? {
        switch envelope.feature {
        case .uploadFile:
            return await uploadHandler.handle(envelope)
        case .reportSighting:
            return await sightingReporter.handle(envelope)
        case .none:
            return nil
        }
    }
}
