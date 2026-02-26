import Compound
import SwiftUI

struct PgMediaUploadBlockedFilesSheetView: View {
    var preferredColorScheme: ColorScheme? = .dark
    let blockedFilenames: [String]
    let canContinue: Bool
    let onContinue: () -> Void
    var controlsPresentationDetents = true
    var onHeightChange: ((CGFloat) -> Void)?

    @State private var sheetHeight: CGFloat = .zero
    private let topPadding: CGFloat = 19

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                blockedFilesList
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

    private var header: some View {
        VStack(spacing: 16) {
            BigIcon(icon: \.block, style: .alertSolid)

            VStack(spacing: 8) {
                Text(L10n.pgDialogFileTypeBlockedTitle)
                    .font(.compound.headingMDBold)
                    .foregroundStyle(.compound.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.pgUploadDialogFileBlockedMessage(blockedFilenames.count))
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 24)
        .padding(.horizontal, 24)
    }

    private var blockedFilesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blockedFilenames, id: \.self) { filename in
                Text(filename)
                    .font(.compound.bodyMDSemibold)
                    .foregroundStyle(.compound.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }

    private var buttons: some View {
        VStack(spacing: 16) {
            Button(canContinue ? L10n.actionContinue : L10n.actionOk) {
                onContinue()
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

// MARK: - Previews

struct PgMediaUploadBlockedFilesAlertView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper(canContinue: true)
            .previewDisplayName("Can Continue")
        
        PreviewWrapper(canContinue: false)
            .previewDisplayName("Cannot Continue")
    }
    
    private struct PreviewWrapper: View {
        let canContinue: Bool
        @State private var isPresented = true
        
        var body: some View {
            Color.black
                .ignoresSafeArea()
                .sheet(isPresented: $isPresented) {
                    PgMediaUploadBlockedFilesSheetView(blockedFilenames: ["document.exe", "script.bat", "archive.zip"],
                                                       canContinue: canContinue,
                                                       onContinue: { })
                }
        }
    }
}
