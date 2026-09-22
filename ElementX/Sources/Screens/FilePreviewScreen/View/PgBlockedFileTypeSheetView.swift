//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// A bottom-sheet alert shown when the user attempts to share or save a blocked file type.
/// Unlike `AttachmentWarningSheetView`, this has no continue option — only a dismiss button.
struct BlockedFileTypeSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var preferredColorScheme: ColorScheme? = .dark
    let filename: String
    let fileExtension: String
    var controlsPresentationDetents = true
    var onHeightChange: ((CGFloat) -> Void)?

    @State private var sheetHeight: CGFloat = .zero
    private let topPadding: CGFloat = 19

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                buttons
            }
            .readHeight($sheetHeight)
        }
        .onChange(of: sheetHeight) { _, newValue in
            onHeightChange?(newValue + topPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(.top, topPadding)
        .modifier(PresentationDetentsModifier(isEnabled: controlsPresentationDetents,
                                              height: sheetHeight + topPadding))
        .presentationDragIndicator(.visible)
        .presentationBackground(.compound.bgCanvasDefault)
        .preferredColorScheme(preferredColorScheme)
    }

    private var styledMessage: AttributedString {
        let filenamePlaceholder = "{filename}"
        let extensionPlaceholder = "{extension}"

        var message = AttributedString(L10n.pgDialogFileTypeBlockedMessage(filenamePlaceholder, extensionPlaceholder))
        message.foregroundColor = .compound.textSecondary

        var styledFilename = AttributedString(filename)
        styledFilename.foregroundColor = .compound.textPrimary
        message.replace(filenamePlaceholder, with: styledFilename)

        var styledExtension = AttributedString(fileExtension)
        styledExtension.foregroundColor = .compound.textPrimary
        message.replace(extensionPlaceholder, with: styledExtension)

        return message
    }

    private var header: some View {
        VStack(spacing: 16) {
            BigIcon(icon: \.block, style: .alertSolid)
            VStack(spacing: 8) {
                Text(L10n.pgDialogFileTypeBlockedTitle)
                    .font(.compound.headingMDBold)
                    .foregroundStyle(.compound.textPrimary)
                    .multilineTextAlignment(.center)
                Text(styledMessage)
                    .font(.compound.bodyMD)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
        .padding(.horizontal, 24)
    }

    private var buttons: some View {
        VStack(spacing: 16) {
            Button(L10n.actionOk) {
                dismiss()
            }
            .buttonStyle(.compound(.primary))
        }
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
    }
}

private struct PresentationDetentsModifier: ViewModifier {
    let isEnabled: Bool
    let height: CGFloat

    func body(content: Content) -> some View {
        if isEnabled {
            content.presentationDetents([.height(height)])
        } else {
            content
        }
    }
}

struct BlockedFileTypeAlertView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper(preferredColorScheme: .dark)
            .previewDisplayName("Blocked File Type (Dark)")
        PreviewWrapper(preferredColorScheme: .light)
            .previewDisplayName("Blocked File Type (Light)")
    }

    private struct PreviewWrapper: View {
        let preferredColorScheme: ColorScheme?
        @State private var isPresented = true

        var body: some View {
            Color.black
                .ignoresSafeArea()
                .sheet(isPresented: $isPresented) {
                    BlockedFileTypeSheetView(preferredColorScheme: preferredColorScheme,
                                             filename: "malware.exe",
                                             fileExtension: ".exe")
                }
        }
    }
}
