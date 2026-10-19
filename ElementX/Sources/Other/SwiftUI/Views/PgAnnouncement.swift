//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

enum PgAnnouncementType {
    case informative(isCritical: Bool = false)
    /// The dismiss button is shown only when `onDismiss` is provided.
    case actionable(actionTitle: String, action: () -> Void, onDismiss: (() -> Void)?, isCritical: Bool = false)
    
    var isCritical: Bool {
        switch self {
        case .informative(let isCritical), .actionable(_, _, _, let isCritical):
            isCritical
        }
    }
}

struct PgAnnouncement: View {
    let title: String?
    let message: String
    let type: PgAnnouncementType
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                CompoundIcon(type.isCritical ? \.errorSolid : \.infoSolid, size: .small, relativeTo: .compound.bodyLG)
                    .foregroundStyle(type.isCritical ? .compound.iconCriticalPrimary : .compound.iconAccentPrimary)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.compound.bodyLGSemibold)
                            .foregroundColor(.compound.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    
                    Text(message)
                        .font(.compound.bodyMD)
                        .foregroundColor(.compound.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if case let .actionable(_, _, onDismiss?, _) = type {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.compound.iconSecondary)
                            .frame(width: 12, height: 12)
                    }
                    .accessibilityLabel(L10n.actionClose)
                    .padding(.top, 4)
                }
            }
            
            if case let .actionable(actionTitle, action, _, _) = type {
                Button(action: action) {
                    Text(actionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.primary, size: .medium))
            }
        }
        .padding(16)
        .background(Color.compound.bgSubtleSecondary)
        .cornerRadius(14)
    }
}

struct PgAnnouncement_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(spacing: 16) {
            PgAnnouncement(title: "Why am I seeing this?",
                           message: "This device is new to your account. Verifying it unlocks your encrypted messages.",
                           type: .informative())
            
            PgAnnouncement(title: "You will need to reset your digital identity",
                           message: "You have no other verified device and no recovery key.",
                           type: .informative(isCritical: true))
            
            PgAnnouncement(title: nil,
                           message: "A short critical notice without a title.",
                           type: .informative(isCritical: true))
        }
        .padding()
    }
}
