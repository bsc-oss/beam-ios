//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-09-28

import Compound
import SwiftUI

struct IdentityConfirmationScreen: View {
    @Bindable var context: IdentityConfirmationScreenViewModel.Context
    
    var shouldShowSkipButton: Bool {
        #if DEBUG
        !ProcessInfo.isRunningTests
        #else
        false
        #endif
    }
    
    var body: some View {
        FullscreenDialog(topPadding: UIConstants.startScreenBreakerScreenTopPadding) {
            screenHeader
        } bottomContent: {
            actionButtons
        }
        .toolbar { toolbar }
        .background()
        .backgroundStyle(.compound.bgCanvasDefault)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled()
        .alert(item: $context.alertInfo)
    }
    
    // MARK: - Private
    
    private var screenHeader: some View {
        VStack(spacing: 0) {
            BigIcon(icon: \.lockSolid)
                .padding(.bottom, 16)
            
            Text(L10n.screenIdentityConfirmationTitle)
                .font(.compound.headingMDBold)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textPrimary)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
            
            Text(L10n.screenIdentityConfirmationSubtitle)
                .font(.compound.bodyMD)
                .multilineTextAlignment(.center)
                .foregroundColor(.compound.textSecondary)
            
            // PG_CHANGED - explain why the user is on this screen, and warn when a reset is the only way forward.
            VStack(spacing: 16) {
                PgAnnouncement(title: L10n.pgScreenIdentityConfirmationWhyTitle,
                               message: L10n.pgScreenIdentityConfirmationWhyDescription,
                               type: .informative())
                
                if context.viewState.needsIdentityReset {
                    PgAnnouncement(title: L10n.pgScreenIdentityConfirmationResetNeededTitle,
                                   message: L10n.pgScreenIdentityConfirmationResetNeededDescription,
                                   type: .informative(isCritical: true))
                }
                
                learnMoreLink
            }
            .padding(.top, 16)
        }
    }
    
    // PG_CHANGED - render 'Learn more' as an external link.
    private var learnMoreLink: some View {
        Button {
            UIApplication.shared.open(context.viewState.learnMoreURL)
        } label: {
            HStack(spacing: 4) {
                Text(L10n.actionLearnMore)
                    .underline()
                CompoundIcon(\.popOut, size: .small, relativeTo: .compound.bodyLGSemibold)
            }
            .foregroundStyle(.compound.textLinkExternal)
        }
        .buttonStyle(.compound(.textLink))
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if let availableActions = context.viewState.availableActions {
                if availableActions.contains(.interactiveVerification) {
                    Button(L10n.screenIdentityConfirmationUseAnotherDevice) {
                        context.send(viewAction: .otherDevice)
                    }
                    .buttonStyle(.compound(.primary))
                }
                
                if availableActions.contains(.recovery) {
                    Button(L10n.screenIdentityConfirmationUseRecoveryKey) {
                        context.send(viewAction: .recoveryKey)
                    }
                    .buttonStyle(.compound(.primary))
                }
                
                // PG_CHANGED - resetting is the only way forward, so make it the prominent (destructive) action.
                if context.viewState.needsIdentityReset {
                    Button(L10n.actionResetIdentity, role: .destructive) {
                        context.send(viewAction: .reset)
                    }
                    .buttonStyle(.compound(.primary))
                } else {
                    Button(L10n.screenIdentityConfirmationCannotConfirm) {
                        context.send(viewAction: .reset)
                    }
                    .buttonStyle(.compound(.secondary))
                }
            } else {
                Button { /* Placeholder button, there is no action */ } label: {
                    Label {
                        Text(L10n.commonLoading)
                    } icon: {
                        ProgressView()
                            .tint(.compound.iconOnSolidPrimary)
                    }
                }
                .buttonStyle(.compound(.primary))
                .disabled(true)
            }
            
            if shouldShowSkipButton {
                Button("\(L10n.actionSkip) 🙉") {
                    context.send(viewAction: .skip)
                }
                .buttonStyle(.compound(.tertiary))
            }
        }
    }
    
    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .destructiveAction) {
            Button(L10n.actionSignout) {
                context.send(viewAction: .logout)
            }
        }
    }
}

// MARK: - Previews

@available(iOS 26.0, *)
struct IdentityConfirmationScreen_Previews: PreviewProvider, TestablePreview {
    static var viewModel = makeViewModel()
    static var loadingViewModel = makeViewModel(recoveryState: .unknown)
    static var resetNeededViewModel = makeViewModel(recoveryState: .disabled, hasDevicesToVerifyAgainst: false) // PG_CHANGED
    
    static var previews: some View {
        ElementNavigationStack {
            IdentityConfirmationScreen(context: viewModel.context)
        }
        .previewDisplayName("Actions")
        .snapshotPreferences(expect: viewModel.context.observe(\.viewState.availableActions).map { actions in
            actions?.contains([.interactiveVerification, .recovery]) == true
        })
        
        ElementNavigationStack {
            IdentityConfirmationScreen(context: loadingViewModel.context)
        }
        .previewDisplayName("Loading")
        
        // PG_CHANGED
        ElementNavigationStack {
            IdentityConfirmationScreen(context: resetNeededViewModel.context)
        }
        .previewDisplayName("Reset needed")
        .snapshotPreferences(expect: resetNeededViewModel.context.observe(\.viewState.needsIdentityReset))
    }
    
    static func makeViewModel(recoveryState: SecureBackupRecoveryState = .enabled,
                              hasDevicesToVerifyAgainst: Bool = true) -> IdentityConfirmationScreenViewModel { // PG_CHANGED - hasDevicesToVerifyAgainst
        let clientProxy = ClientProxyMock(.init())
        clientProxy.hasDevicesToVerifyAgainstReturnValue = .success(hasDevicesToVerifyAgainst) // PG_CHANGED
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        userSession.sessionSecurityStatePublisher = CurrentValuePublisher<SessionSecurityState, Never>(.init(verificationState: .unverified, recoveryState: recoveryState))
        
        return IdentityConfirmationScreenViewModel(userSession: userSession,
                                                   appSettings: .volatile(),
                                                   userIndicatorController: UserIndicatorControllerMock())
    }
}
