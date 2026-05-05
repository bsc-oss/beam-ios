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

import Compound
import SwiftUI

struct JoinCallButton: View {
    let action: () -> Void
    
    var body: some View {
        if #available(iOS 26, *) {
            glassButton
        } else {
            customButton
        }
    }
    
    var glassButton: some View {
        Button(action: action) {
            // Use an HStack on iOS 26 as .labelStyle(.titleAndIcon) doesn't
            // seem to have any effect on a label in the navigation bar 🤷‍♂️
            HStack(spacing: 6) {
                // PG_CHANGED - shows voice call icon instead of video call icon
                CompoundIcon(\.voiceCallSolid)
                Text(L10n.actionJoin)
                    .padding(.trailing, 4)
            }
            .font(.compound.bodyLG.weight(.medium))
            .foregroundStyle(.compound.textOnSolidPrimary)
        }
        .tint(.compound.bgActionPrimaryRest)
        .backportButtonStyleGlassProminent()
        .accessibilityLabel(L10n.a11yJoinCall)
    }
    
    var customButton: some View {
        Button(action: action) {
            // PG_CHANGED - shows voice call icon instead of video call icon
            Label(L10n.actionJoin, icon: \.voiceCallSolid)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(CustomStyle())
        .accessibilityLabel(L10n.a11yJoinCall)
    }
    
    struct CustomStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.horizontal, 16.0)
                .padding(.vertical, 4.0)
                .foregroundColor(.compound.bgCanvasDefault)
                .background(Color.compound.iconAccentTertiary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Previews

struct JoinCallButton_Previews: PreviewProvider {
    static var previews: some View {
        ElementNavigationStack {
            Color.clear
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        JoinCallButton { }
                    }
                }
        }
    }
}
