//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct PgEmailInputScreen: View {
    @Bindable var context: PgEmailInputScreenViewModel.Context
    @FocusState private var isEmailTextFieldFocused: Bool
    @State private var hasAcceptedTermsAndConditions = false
    
    var body: some View {
        FullscreenDialog {
            VStack(spacing: 16) {
                header
                mainContent
            }
        } bottomContent: {
            buttons
        }
        .background()
        .backgroundStyle(.compound.bgCanvasDefault)
        .alert(item: $context.alertInfo)
        .introspect(.window, on: .supportedVersions) { window in
            context.send(viewAction: .updateWindow(window))
        }
    }
    
    var header: some View {
        VStack(spacing: 8) {
            BigIcon(icon: \.emailSolid, style: .defaultSolid)
                .padding(.bottom, 8)
            
            Text(L10n.pgEmailInputScreenTitle)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
    
            Text(L10n.pgEmailInputScreenSubtitle)
                .font(.compound.bodyMD)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textSecondary)
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    var mainContent: some View {
        VStack(spacing: 8) {
            TextField(text: $context.email) {
                HStack(spacing: 8) {
                    Image(systemSymbol: .envelope)
                    Text(L10n.pgEmailInputScreenEmailInputPlaceholder).foregroundColor(.compound.textSecondary)
                }
            }
            .textFieldStyle(.element(footerText: Text(context.viewState.footerErrorMessage ?? ""),
                                     state: context.viewState.isShowingFooterError ? .error : .default,
                                     accessibilityIdentifier: A11yIdentifiers.pgEmailInputScreen.emailtextField))
            .disableAutocorrection(true)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .submitLabel(.continue)
            .focused($isEmailTextFieldFocused)
            .onAppear { DispatchQueue.main.async { isEmailTextFieldFocused = true } }
            .onChange(of: context.email) { context.send(viewAction: .clearFooterError) }
            .onSubmit { confirm() }
            
            PgCheckbox(isChecked: $hasAcceptedTermsAndConditions) {
                Text(makeTermsAndConditionsText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// The action buttons shown at the bottom of the view.
    var buttons: some View {
        VStack(spacing: 16) {
            Button { confirm() } label: {
                Text(L10n.actionContinue)
            }
            .buttonStyle(.compound(.primary))
            .accessibilityIdentifier(A11yIdentifiers.pgEmailInputScreen.continueButton)
            .disabled(isEmailEmpty || !hasAcceptedTermsAndConditions || context.viewState.isLoading)
        }
    }
    
    // MARK: - private
    
    private func confirm() {
        if !isEmailEmpty, hasAcceptedTermsAndConditions {
            context.send(viewAction: .confirm)
        }
    }
    
    private var isEmailEmpty: Bool {
        context.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func makeTermsAndConditionsText() -> AttributedString {
        var message = AttributedString(L10n.pgEmailInputScreenTermsAndConditionsMessage)
        message.font = .compound.bodyLG
        message.foregroundColor = .compound.textPrimary
        
        var linkText = AttributedString(L10n.pgEmailInputScreenTermsAndConditionsLinkText)
        linkText.link = context.viewState.acceptableUseURL
        linkText.foregroundColor = .compound.textTertiary
        linkText.font = .compound.bodyLGSemibold
        
        return message + " " + linkText
    }
}

// MARK: - Previews

struct PgEmailInputScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let viewModelWithFooterError = makeViewModel(footerErrorMessage: "Footer error message")
    
    static var previews: some View {
        ElementNavigationStack {
            PgEmailInputScreen(context: viewModel.context)
                .toolbar(.visible, for: .navigationBar)
        }
        .previewDisplayName("Login")
        
        ElementNavigationStack {
            PgEmailInputScreen(context: viewModelWithFooterError.context)
                .toolbar(.visible, for: .navigationBar)
        }
        .previewDisplayName("With footer error message")
    }
    
    static func makeViewModel(footerErrorMessage: String? = nil) -> PgEmailInputScreenViewModel {
        let vm = PgEmailInputScreenViewModel(authenticationService: AuthenticationService.mock,
                                             pgEmailValidationService: PgEmailValidationService.mock,
                                             userIndicatorController: UserIndicatorControllerMock(),
                                             appSettings: AppSettings())
        
        vm.state.footerErrorMessage = footerErrorMessage
        
        return vm
    }
}
