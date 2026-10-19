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
    // PG_CHANGED - three-tier phonebook consent system
    @State private var showPhoneBookConsentSheet = false
    
    var body: some View {
        Form {
            Section {
                avatar
            } footer: {
                // PG_CHANGED - display email instead of mxid
                Text(context.viewState.currentUserProfile.emailOrId)
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
        // PG_CHANGED - a field over its character limit blocks saving, but the changes are still unsaved
        .navigationBarBackButtonHidden(context.viewState.hasUnsavedChanges)
        .toolbar { toolbar }
        .alert(item: $context.alertInfo)
    }
    
    // MARK: - Private
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            // PG_CHANGED - Cancel stays available while a field is over its character limit
            if context.viewState.hasUnsavedChanges {
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
                                   name: context.viewState.currentUserProfile.displayName,
                                   contentID: context.viewState.currentUserProfile.id,
                                   shape: .circle,
                                   avatarSize: .user(on: .editUserDetails),
                                   mediaProvider: context.mediaProvider)
                .confirmationDialog("", isPresented: $context.showMediaSheet) {
                    mediaActionSheet
                }
        }
        .buttonStyle(EditAvatarButtonStyle())
        .disabled(!context.viewState.canEditAvatar)
        .accessibilityLabel(L10n.a11yEditAvatar)
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }
    
    private var nameSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.screenEditProfileDisplayNamePlaceholder),
                    // PG_CHANGED - max length feedback
                    kind: .textField(text: $context.name,
                                     axis: .horizontal,
                                     supportingText: supportingText(for: context.viewState.displayNameLength)))
                .focused($focus)
                .disabled(!context.viewState.canEditDisplayName)
        } header: {
            Text(L10n.screenEditProfileDisplayName)
                .compoundListSectionHeader()
        }
    }
    
    // PG_CHANGED - adds custom profile fields
    private var functionSection: some View {
        Section {
            ListRow(label: .plain(title: L10n.pgScreenEditProfileFunctionPlaceholder),
                    // PG_CHANGED - max length feedback
                    kind: .textField(text: functionBinding,
                                     axis: .horizontal,
                                     supportingText: supportingText(for: context.viewState.functionLength)))
                .focused($focus)
        } header: {
            Text(L10n.pgScreenEditProfileFunction)
                .compoundListSectionHeader()
        } footer: {
            Text(L10n.pgScreenEditProfileFunctionFooter($context.department.wrappedValue)).compoundListSectionFooter()
        }
    }
    
    /// Custom binding that tracks user edits to the function field
    private var functionBinding: Binding<String> {
        Binding(get: { context.viewState.displayFunction },
                set: { context.function = $0 })
    }
    
    // PG_CHANGED - values over the character limit are flagged on the field rather than truncated
    private func supportingText(for length: UserDetailsEditScreenFieldLength) -> ListRowSupportingText? {
        if let errorDescription = length.errorDescription {
            ListRowSupportingText(errorDescription, validity: .invalid)
        } else if let counterDescription = length.counterDescription {
            ListRowSupportingText(counterDescription, accessibilityLabel: length.counterAccessibilityLabel)
        } else {
            nil
        }
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
                    kind: .copyableText(text: context.viewState.currentUserProfile.userID))
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
        
        Button {
            context.send(viewAction: .displayFilePicker)
        } label: {
            Text(L10n.actionChooseFile)
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
    static let viewModel = makeViewModel()
    static let readOnlyViewModel = makeViewModel(canChangeProfile: false)
    
    // PG_CHANGED - adds custom profile fields
    static let fromOnboardingViewModel = UserDetailsEditScreenViewModel(userSession: UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@stefan:matrix.org")))),
                                                                        mediaUploadingPreprocessor: .init(appSettings: AppSettings.volatile()),
                                                                        userIndicatorController: UserIndicatorControllerMock(),
                                                                        isScreenLoadedFromOnboardingFlow: true)
    
    // PG_CHANGED - max length validation. 40 and 41 characters, so both fields show their counter.
    static let nearCharacterLimitViewModel = makeProfileViewModel(displayName: "Alexander Maximilian Von Habsburg Junior",
                                                                  function: "Deputy Director of Digital Transformation")
    
    // PG_CHANGED - 51 and 56 characters, exercising the singular and plural over-limit messages.
    static let overCharacterLimitViewModel = makeProfileViewModel(displayName: "Alexander Maximilian Von Habsburg Junior Of Belgium",
                                                                  function: "Deputy Director of Digital Transformation and Innovation")
    
    static var previews: some View {
        ElementNavigationStack {
            UserDetailsEditScreen(context: viewModel.context)
        }
        .previewDisplayName("Default")
        
        ElementNavigationStack {
            UserDetailsEditScreen(context: readOnlyViewModel.context)
        }
        .previewDisplayName("Read Only")
        
        // PG_CHANGED - adds custom profile fields
        ElementNavigationStack {
            UserDetailsEditScreen(context: fromOnboardingViewModel.context)
        }
        .previewDisplayName("From onboarding")
        
        // PG_CHANGED - max length validation
        ElementNavigationStack {
            UserDetailsEditScreen(context: nearCharacterLimitViewModel.context)
        }
        .previewDisplayName("Near character limit")
        
        ElementNavigationStack {
            UserDetailsEditScreen(context: overCharacterLimitViewModel.context)
        }
        .previewDisplayName("Over character limit")
    }
    
    static func makeViewModel(canChangeProfile: Bool = true) -> UserDetailsEditScreenViewModel {
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@stefan:matrix.org",
                                                                                   displayName: "Stefan",
                                                                                   canChangeAvatar: canChangeProfile,
                                                                                   canChangeDisplayName: canChangeProfile))))
        
        return UserDetailsEditScreenViewModel(userSession: userSession,
                                              mediaUploadingPreprocessor: .init(appSettings: .volatile()),
                                              userIndicatorController: UserIndicatorControllerMock())
    }
    
    // PG_CHANGED - the custom profile fields aren't part of the mock's configuration, so publish a profile directly
    static func makeProfileViewModel(displayName: String, function: String) -> UserDetailsEditScreenViewModel {
        let clientProxy = ClientProxyMock(.init(userID: "@stefan:matrix.org", displayName: displayName))
        clientProxy.userProfilePublisher = .init(UserProfile(userID: "@stefan:matrix.org",
                                                             displayName: displayName,
                                                             department: "Justitie",
                                                             function: function))
        
        return UserDetailsEditScreenViewModel(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                              mediaUploadingPreprocessor: .init(appSettings: .volatile()),
                                              userIndicatorController: UserIndicatorControllerMock())
    }
}
