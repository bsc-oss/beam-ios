//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import SwiftUI

// PG_CHANGED

struct AuthenticationStartLogo: View {
    var body: some View {
        Image(asset: Asset.Images.appLogo)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

struct AuthenticationStartLogo_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        AuthenticationStartLogo()
    }
}
