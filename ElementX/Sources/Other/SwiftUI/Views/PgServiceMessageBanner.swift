//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// Banner that surfaces a remote service message (notice) to the user.
///
/// Two severity levels are supported (informative / critical) which control the icon and accent
/// color. The dismiss button is shown only when both `message.allowDismiss` is true and an
/// `onDismiss` closure is provided (the login screen passes `nil` to make the banner
/// non-dismissible).
struct PgServiceMessageBanner: View {
    let message: PgServiceMessageDisplay
    /// Optional dismiss handler. When `nil`, the banner is rendered without a close button.
    let onDismiss: (() -> Void)?

    private var isDismissible: Bool {
        message.allowDismiss && onDismiss != nil
    }
    
    private var iconKeyPath: KeyPath<CompoundIcons, Image> {
        message.isCritical ? \.errorSolid : \.infoSolid
    }
    
    private var accentColor: Color {
        message.isCritical ? .compound.iconCriticalPrimary : .compound.iconAccentPrimary
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                CompoundIcon(iconKeyPath, size: .small, relativeTo: .compound.bodyLG)
                    .foregroundStyle(accentColor)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    if let title = message.title {
                        Text(title)
                            .font(.compound.bodyLGSemibold)
                            .foregroundColor(.compound.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(message.body)
                        .font(.compound.bodyMD)
                        .foregroundColor(.compound.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let onDismiss, isDismissible {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.compound.iconSecondary)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.top, 4)
                }
            }

            if let onDismiss, isDismissible {
                Button(action: onDismiss) {
                    Text(L10n.actionOk)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.primary, size: .medium))
            }
        }
        .padding(16)
        .background(Color.compound.bgSubtleSecondary)
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }
}

struct PgServiceMessageBanner_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(spacing: 16) {
            PgServiceMessageBanner(message: .init(id: 1,
                                                  isCritical: false,
                                                  allowDismiss: true,
                                                  title: "Scheduled maintenance",
                                                  body: "Beam will be temporarily unavailable on Sunday between 02:00 and 04:00."),
                                   onDismiss: { })
                .previewDisplayName("Informative – dismissible")
            
            PgServiceMessageBanner(message: .init(id: 2,
                                                  isCritical: true,
                                                  allowDismiss: false,
                                                  title: "Service disruption",
                                                  body: "We are currently investigating an issue affecting message delivery."),
                                   onDismiss: nil)
                .previewDisplayName("Critical – non-dismissible")
            
            PgServiceMessageBanner(message: .init(id: 3,
                                                  isCritical: false,
                                                  allowDismiss: true,
                                                  title: nil,
                                                  body: "A short informative notice without a title."),
                                   onDismiss: { })
                .previewDisplayName("Informative – body only")
        }
        .padding(.vertical)
    }
}
