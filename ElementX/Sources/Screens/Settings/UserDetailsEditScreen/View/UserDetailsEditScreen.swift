//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Compound
import SwiftUI

struct UserDetailsEditScreen: View {
    @Bindable var context: UserDetailsEditScreenViewModel.Context
    @FocusState private var focus: Bool
    @State private var showPhoneBookConsentSheet = false
        
    var body: some View {
        Form {
            Section {
                avatar
            } footer: {
                // PG_CHANGED - display email instead of mxid
                Text(context.viewState.userProfile?.emailOrId ?? "")
                    .frame(maxWidth: .infinity)
                    .font(.compound.bodyLG)
                    .foregroundColor(.compound.textPrimary)
                    .padding(.bottom, 16)
            }
            
            nameSection
            
            // PG_CHANGED - adds custom profile fields
            functionSection
            departmentSection
            userIDSection
            if !context.viewState.isScreenLoadedFromOnboardingFlow {
                consentSection
            }
        }
        .compoundList()
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(context.viewState.isScreenLoadedFromOnboardingFlow ? L10n.pgScreenCreateProfileTitle : L10n.screenEditProfileTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(context.viewState.canSave)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
    }
    
    // MARK: - Private
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if context.viewState.canSave {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(L10n.actionSave) {
                context.send(viewAction: .save)
                focus = false
            }
            .disabled(!context.viewState.canSave)
        }
    }

    private var avatar: some View {
        Button {
            context.send(viewAction: .presentMediaSource)
        } label: {
            OverridableAvatarImage(overrideURL: context.viewState.localMedia?.thumbnailURL,
                                   url: context.viewState.selectedAvatarURL,
                                   // PG_CHANGED - adds custom profile fields
                                   name: context.viewState.userProfile?.displayName,
                                   contentID: context.viewState.userID,
                                   shape: .circle,
                                   avatarSize: .user(on: .editUserDetails),
                                   mediaProvider: context.mediaProvider)
                .overlay(alignment: .bottomTrailing) {
                    avatarOverlayIcon
                }
                .confirmationDialog("", isPresented: $context.showMediaSheet) {
                    mediaActionSheet
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }

    private var nameSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.screenEditProfileDisplayNamePlaceholder),
                    kind: .textField(text: $context.name, axis: .horizontal))
                .focused($focus)
        } header: {
            Text(L10n.screenEditProfileDisplayName)
                .compoundListSectionHeader()
        }
    }
    
    // PG_CHANGED - adds custom profile fields
    private var functionSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.pgScreenEditProfileFunctionPlaceholder),
                    kind: .textField(text: functionBinding, axis: .horizontal))
                .focused($focus)
        } header: {
            Text(L10n.pgScreenEditProfileFunction)
                .compoundListSectionHeader()
        } footer: {
            Text(L10n.pgScreenEditProfileFunctionFooter($context.department.wrappedValue)).compoundListSectionFooter()
        }
    }
    
    // Custom binding that tracks user edits to the function field
    private var functionBinding: Binding<String> {
        Binding(get: { context.viewState.displayFunction },
                set: { context.function = $0 })
    }
    
    // PG_CHANGED - adds custom profile fields
    private var departmentSection: some View {
        Section {
            ListRow(label: .plain(title: ""), kind: .textField(text: $context.department, axis: .horizontal))
                .disabled(true)
        } header: {
            Text(L10n.pgScreenEditProfileDepartment).compoundListSectionHeader()
        }
    }
    
    // PG_CHANGED - three-tier phonebook consent system
    private var consentSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.pgScreenEditProfilePhonebookConsentTitle,
                                  description: context.phoneBookConsentType.title),
                    kind: .navigationLink {
                        showPhoneBookConsentSheet = true
                    })
        }
        .sheet(isPresented: $showPhoneBookConsentSheet) {
            PhoneBookConsentSelectionView(selectedType: $context.phoneBookConsentType)
        }
    }
    
    // PG_CHANGED - adds custom profile fields
    private var userIDSection: some View {
        Section {
            // PG_CHANGED - makes the user ID copyable
            ListRow(label: .plain(title: ""),
                    kind: .copyableText(text: context.viewState.userID))
        } header: {
            Text(L10n.pgScreenEditProfileUserID).compoundListSectionHeader()
        }
    }
    
    private var avatarOverlayIcon: some View {
        CompoundIcon(\.editSolid, size: .xSmall, relativeTo: .compound.bodyLG)
            .foregroundColor(.white)
            .padding(4)
            .background {
                Circle()
                    .foregroundColor(.black)
            }
    }
    
    @ViewBuilder
    private var mediaActionSheet: some View {
        Button {
            context.send(viewAction: .displayCameraPicker)
        } label: {
            Text(L10n.actionTakePhoto)
        }
        Button {
            context.send(viewAction: .displayMediaPicker)
        } label: {
            Text(L10n.actionChoosePhoto)
        }
        
        if context.viewState.showDeleteImageAction {
            Button(role: .destructive) {
                context.send(viewAction: .removeImage)
            } label: {
                Text(L10n.actionRemove)
            }
        }
    }
}

// MARK: - Previews

struct UserDetailsEditScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = UserDetailsEditScreenViewModel(userSession: UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@stefan:matrix.org")))),
                                                          mediaUploadingPreprocessor: .init(appSettings: ServiceLocator.shared.settings),
                                                          userIndicatorController: UserIndicatorControllerMock.default)
    
    // PG_CHANGED - adds custom profile fields
    static let fromOnboardingViewModel = UserDetailsEditScreenViewModel(userSession: UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@stefan:matrix.org")))),
                                                                        mediaUploadingPreprocessor: .init(appSettings: ServiceLocator.shared.settings),
                                                                        userIndicatorController: UserIndicatorControllerMock.default,
                                                                        isScreenLoadedFromOnboardingFlow: true)
    
    static var previews: some View {
        ElementNavigationStack {
            UserDetailsEditScreen(context: viewModel.context)
        }

        // PG_CHANGED - adds custom profile fields
        ElementNavigationStack {
            UserDetailsEditScreen(context: fromOnboardingViewModel.context)
        }
        .previewDisplayName("From onboarding")
    }
}
