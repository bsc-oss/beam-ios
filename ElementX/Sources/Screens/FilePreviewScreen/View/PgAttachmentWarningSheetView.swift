
import Compound
import SwiftUI

struct AttachmentWarningSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var preferredColorScheme: ColorScheme? = .dark
    let onContinue: () -> Void
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
        .padding(.top, topPadding) // For the drag indicator
        .modifier(PresentationDetentsModifier(isEnabled: controlsPresentationDetents,
                                              height: sheetHeight + topPadding))
        .presentationDragIndicator(.visible)
        .presentationBackground(.compound.bgCanvasDefault)
        .preferredColorScheme(preferredColorScheme)
    }

    private var header: some View {
        VStack(spacing: 16) {
            BigIcon(icon: \.warning, style: .alertSolid)

            VStack(spacing: 8) {
                Text(L10n.pgAttachmentWarningTitle)
                    .font(.compound.headingMDBold)
                    .foregroundStyle(.compound.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.pgAttachmentWarningMessage)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
        .padding(.horizontal, 24)
    }

    private var buttons: some View {
        VStack(spacing: 16) {
            Button(L10n.actionContinue) {
                onContinue()
            }
            .buttonStyle(.compound(.primary))

            Button(L10n.actionCancel) {
                dismiss()
            }
            .buttonStyle(.compound(.tertiary))
        }
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

// PG_CHANGED
struct AttachmentWarningSheetView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper(preferredColorScheme: .dark)
            .previewDisplayName("Warning Sheet (Dark)")
        
        PreviewWrapper(preferredColorScheme: .light)
            .previewDisplayName("Warning Sheet (Light)")
    }
    
    private struct PreviewWrapper: View {
        let preferredColorScheme: ColorScheme?
        @State private var isPresented = true
        
        var body: some View {
            Color.black
                .ignoresSafeArea()
                .sheet(isPresented: $isPresented) {
                    AttachmentWarningSheetView(preferredColorScheme: preferredColorScheme) {
                        // Continue action
                    }
                }
        }
    }
}
