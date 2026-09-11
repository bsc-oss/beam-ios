//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import PGArgusMobileBrownfield
import SwiftUI

/// Hosts the Argus React Native bundle full-screen.
final class PgArgusReactNativeCoordinator: CoordinatorProtocol {
    /// Shared-state keys read by the Argus bundle (`src/services/host-config-service.ts`
    /// in pg-argus-mobile) — keep the two in sync.
    private static let mapTileServerUrlStateKey = "mapTileServerUrl"
    private static let localeStateKey = "locale"

    init(mapTileServerUrl: String) {
        // Hand this environment's tile server to the RN bundle. BrownfieldState is a
        // process-global registry, safe to write before the RN view mounts; the write
        // is idempotent across repeated presentations.
        BrownfieldState.set(Self.mapTileServerUrlStateKey, mapTileServerUrl)
        MXLog.info("Argus host config: shared map tile server URL: \(mapTileServerUrl)")

        // Hand over the language the app is actually rendering in, so the embedded Argus
        // screens match the rest of the UI instead of always falling back to English.
        // preferredLocalizations resolves our bundle against the user's preferred
        // languages, which is what L10n reads, so it also honours the per-app language
        // override in iOS Settings. The bundle ships localisations Argus doesn't
        // translate; narrowing that down is the RN side's job.
        //
        // Unlike the tile server, this can be read at module scope on the RN side, and
        // the RN host boots back in AppDelegate — so the bundle may already be running
        // by the time we get here. The RN side also subscribes to this key for that
        // reason; see `syncLanguageWithHost` in pg-argus-mobile.
        let locale = Bundle.app.preferredLocalizations.first ?? "en"
        BrownfieldState.set(Self.localeStateKey, locale)
        MXLog.info("Argus host config: shared locale: \(locale)")
    }

    func toPresentable() -> AnyView {
        // ignoresSafeArea so the RN view fills the cover edge-to-edge; otherwise SwiftUI
        // insets it to the safe area and the top/bottom gaps show white.
        AnyView(ReactNativeView(moduleName: "main")
            .ignoresSafeArea())
    }
}

/// Invisible content for the Argus launcher tab.
final class PgArgusTabPlaceholderCoordinator: CoordinatorProtocol {
    func toPresentable() -> AnyView {
        AnyView(Color.compound.bgCanvasDefault)
    }
}
