import Compound
import SwiftUI

struct PhoneBookConsentSelectionView: View {
    @Binding var selectedType: PhoneBookConsentType
    @Environment(\.dismiss) private var dismiss
    @State private var expandedTypes: Set<PhoneBookConsentType> = []
    @State private var localSelection: PhoneBookConsentType = .default

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        optionsSection
                        Spacer(minLength: 16)
                        disclaimerSection
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }
            .background(Color.compound.bgCanvasDefault)
            .navigationTitle(L10n.pgScreenEditProfilePhonebookConsentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(L10n.actionContinue) {
                    selectedType = localSelection
                    dismiss()
                }
                .buttonStyle(.compound(.primary))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.compound.bgCanvasDefault)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear { localSelection = selectedType }
        }
    }

    // MARK: - Private

    private var headerSection: some View {
        Text(L10n.pgScreenEditProfilePhonebookConsentDescription)
            .font(.compound.bodyMD)
            .foregroundColor(.compound.textSecondary)
    }

    private var optionsSection: some View {
        VStack(spacing: 12) {
            ForEach(PhoneBookConsentType.allCases, id: \.self) { type in
                consentOptionCard(for: type)
            }
        }
    }

    private func consentOptionCard(for type: PhoneBookConsentType) -> some View {
        let isExpanded = expandedTypes.contains(type)
        let isSelected = localSelection == type

        return VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            HStack(alignment: .center, spacing: 16) {
                // Radio button
                Button {
                    localSelection = type
                } label: {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.compound.iconAccentPrimary,
                                          lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .fill(Color.compound.iconAccentPrimary)
                                    .frame(width: 10, height: 10)
                            )
                    } else {
                        Circle()
                            .strokeBorder(Color.compound.borderInteractiveSecondary,
                                          lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }
                // Tab Area for easier tapping
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .buttonStyle(.plain)

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.compound.bodyLGSemibold)
                        .foregroundColor(.compound.textPrimary)

                    Text(type.subtitle)
                        .font(.compound.bodySM)
                        .foregroundColor(.compound.textSecondary)
                }

                Spacer()

                // Chevron
                CompoundIcon(isExpanded ? \.chevronUp : \.chevronDown,
                             size: .medium,
                             relativeTo: .compound.bodyLG)
                    .foregroundColor(.compound.iconSecondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Bullet points
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(type.bulletPoints, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.compound.bodySM)
                                    .foregroundColor(.compound.textSecondary)
                                Text(bullet)
                                    .font(.compound.bodySM)
                                    .foregroundColor(.compound.textSecondary)
                            }
                        }
                    }

                    // Warning (if any)
                    if let warning = type.warningText {
                        HStack(alignment: .top, spacing: 16) {
                            CompoundIcon(\.warning,
                                         size: .small,
                                         relativeTo: .compound.bodySM)
                                .foregroundColor(.compound.iconQuaternary)
                                .frame(width: 8, alignment: .center)
                            Text(warning)
                                .font(.compound.bodySM)
                                .foregroundColor(.compound.textPrimary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.leading, 72) // Align with text after radio button (16 padding + 40 button + 16 spacing)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.compound.bgCanvasDefault)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.compound.borderInteractiveSecondary,
                              lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedTypes.contains(type) {
                    expandedTypes.remove(type)
                } else {
                    expandedTypes.insert(type)
                }
            }
        }
    }

    private var disclaimerSection: some View {
        Text(L10n.pgScreenEditProfilePhonebookConsentDisclaimer)
            .font(.compound.bodySM)
            .foregroundColor(.compound.textSecondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.compound.bgSubtleSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Previews

struct PhoneBookConsentSelectionView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        PhoneBookConsentSelectionView(selectedType: .constant(.full))
            .previewDisplayName("Full (Default)")
        
        PhoneBookConsentSelectionView(selectedType: .constant(.limited))
            .previewDisplayName("Limited")
        
        PhoneBookConsentSelectionView(selectedType: .constant(.none))
            .previewDisplayName("None")
    }
}
