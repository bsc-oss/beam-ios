//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Compound
import SwiftUI

// PG_CHANGED - makes the user ID copyable

/// A button that contains text that is copied on tap
struct CopyTextButton: View {
    let content: String
    var font: Font = .compound.bodyLG
    var iconSize: CompoundIcon.Size = .small
    
    @State private var showCopiedConfirmation = false
    @State private var confirmationTask: Task<Void, Never>?

    var body: some View {
        Button {
            UIPasteboard.general.string = content
            confirmationTask?.cancel()
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedConfirmation = true
            }
            confirmationTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedConfirmation = false
                }
            }
        } label: {
            Label {
                Text(content)
                    .lineLimit(1)
            } icon: {
                if showCopiedConfirmation {
                    CompoundIcon(\.check, size: iconSize, relativeTo: font)
                        .foregroundStyle(.compound.iconSuccessPrimary)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                } else {
                    CompoundIcon(\.copy, size: iconSize, relativeTo: font)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .font(font)
            .foregroundStyle(.compound.textSecondary)
            .labelStyle(.custom(spacing: 4, iconLayout: .trailing))
        }
        .accessibilityHint(L10n.actionCopy)
    }
}

struct CopyTextButton_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(spacing: 8) {
            CopyTextButton(content: "Copy me!")
            CopyTextButton(content: "Copy me!", font: .compound.bodyMD, iconSize: .xSmall)
        }
    }
}
