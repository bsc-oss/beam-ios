//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-09-25

import Compound
import SwiftUI

struct InviteUsersScreen: View {
    @ObservedObject var context: InviteUsersScreenViewModel.Context
    
    @State private var formWidth = CGFloat.zero
    
    var showTopSection: Bool {
        !context.viewState.selectedUsers.isEmpty || context.viewState.isSearching
    }
    
    var body: some View {
        mainContent
            .compoundList()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(L10n.screenCreateRoomAddPeopleTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .searchController(query: $context.searchQuery,
                              placeholder: L10n.commonSearchForSomeone,
                              showsCancelButton: false,
                              disablesInteractiveDismiss: true,
                              accessibilityFocusOnStart: true)
            .compoundSearchField()
            .sheet(isPresented: $context.presentConfirmationDialog) {
                InviteUsersConfirmationSheetView(context: context, users: context.viewState.usersToConfirm)
            }
            .alert(item: $context.alertInfo)
            .navigationBarBackButtonHidden(context.viewState.isSkippable)
    }
    
    // MARK: - Private
    
    private var mainContent: some View {
        Form {
            if showTopSection {
                // this is a fix for having the carousel not clipped, and inside the form, so when the search is dismissed, it wont break the design
                Section {
                    EmptyView()
                } header: {
                    VStack(spacing: 16) {
                        selectedUsersSection
                            .textCase(.none)
                            .frame(width: formWidth)
                        
                        if context.viewState.isSearching {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            
            if context.viewState.hasEmptySearchResults {
                noResultsContent
            } else {
                usersSection
            }
        }
        .readWidth($formWidth)
    }
    
    private var noResultsContent: some View {
        // PG_CHANGED - the refusal when rate limited
        Text(context.viewState.usersSection.emptyResultsText)
            .font(.compound.bodyLG)
            .foregroundColor(context.viewState.usersSection.isRateLimited ? .compound.textCriticalPrimary : .compound.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .accessibilityIdentifier(A11yIdentifiers.startChatScreen.searchNoResults)
    }
    
    @ViewBuilder
    private var usersSection: some View {
        if !context.viewState.usersSection.users.isEmpty {
            Section {
                ForEach(context.viewState.usersSection.users, id: \.id) { user in
                    UserProfileListRow(user: user,
                                       membership: context.viewState.membershipState(user),
                                       mediaProvider: context.mediaProvider,
                                       kind: .multiSelection(isSelected: context.viewState.isUserSelected(user)) {
                                           context.send(viewAction: .toggleUser(user))
                                       },
                                       // PG_CHANGED
                                       isFromExistingChat: context.viewState.usersSection.knownFromRoomUserIDs.contains(user.id))
                        .disabled(context.viewState.isUserDisabled(user))
                        .accessibilityIdentifier(A11yIdentifiers.inviteUsersScreen.userProfile)
                }
            } header: {
                UserDiscoverySectionHeader(section: context.viewState.usersSection) // PG_CHANGED
            }
        } else {
            Section.empty
        }
    }
    
    @ScaledMetric private var selectedUserCellWidth: CGFloat = 80
    
    private var selectedUsersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(context.viewState.selectedUsers, id: \.id) { user in
                    InviteUsersScreenSelectedItem(user: user,
                                                  mediaProvider: context.mediaProvider,
                                                  isLocked: context.viewState.isInviteeMandatory(user)) {
                        deselect(user)
                    }
                    .frame(width: selectedUserCellWidth)
                }
            }
            .padding(.horizontal, 16)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $context.selectedUsersPosition, anchor: .trailing)
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if !context.viewState.isSkippable {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.actionCancel) {
                    context.send(viewAction: .cancel)
                }
            }
        }
        
        ToolbarItem(placement: .confirmationAction) {
            if context.viewState.isSkippable, context.viewState.selectedUsers.isEmpty {
                Button(L10n.actionSkip) {
                    context.send(viewAction: .proceed)
                }
                .accessibilityIdentifier(A11yIdentifiers.inviteUsersScreen.proceed)
            } else {
                ToolbarButton(role: .confirm(title: L10n.actionInvite)) {
                    context.send(viewAction: .proceed)
                }
                .accessibilityIdentifier(A11yIdentifiers.inviteUsersScreen.proceed)
                .disabled(!context.viewState.hasInvitableSelectedUsers)
            }
        }
    }
    
    private func deselect(_ user: UserProfile) {
        context.send(viewAction: .toggleUser(user))
    }
}

// MARK: - Previews

struct InviteUsersScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let searchingViewModel = makeViewModel(searchQuery: "Alice")
    static let selectedViewModel = makeViewModel(hasSelection: true)
    static let confirmSelectedViewModel = makeViewModel(shouldConfirm: true)
    static let draftViewModel = makeViewModel(roomType: .draft(mandatoryInvitees: [.mockAlice]), isSkippable: false)
    // PG_CHANGED
    static let rateLimitedViewModel = makeViewModel(searchQuery: "Alice",
                                                    searchResults: .init(results: [], serverError: .rateLimited))
    static let localResultsOnlyViewModel = makeViewModel(searchQuery: "Alice",
                                                         searchResults: .init(results: [.mockAlice],
                                                                              knownFromRoomUserIDs: [UserProfile.mockAlice.id],
                                                                              serverError: .unavailable))
    
    static var previews: some View {
        ElementNavigationStack {
            InviteUsersScreen(context: viewModel.context)
        }
        .previewDisplayName("Suggestions")
        .snapshotPreferences(expect: viewModel.context.$viewState.map { !$0.usersSection.users.isEmpty })
        
        ElementNavigationStack {
            InviteUsersScreen(context: searchingViewModel.context)
        }
        .previewDisplayName("Searching")
        .snapshotPreferences(expect: searchingViewModel.context.$viewState.map {
            $0.usersSection.type == .searchResult && !$0.usersSection.users.isEmpty
        })
        
        ElementNavigationStack {
            InviteUsersScreen(context: selectedViewModel.context)
        }
        .previewDisplayName("Selected")
        .snapshotPreferences(expect: selectedViewModel.context.$viewState.map { !$0.selectedUsers.isEmpty })
        
        ElementNavigationStack {
            InviteUsersScreen(context: confirmSelectedViewModel.context)
        }
        .previewDisplayName("Confirm Selected")
        
        ElementNavigationStack {
            InviteUsersScreen(context: draftViewModel.context)
        }
        .previewDisplayName("Draft (locked invitee)")
        .snapshotPreferences(expect: draftViewModel.context.$viewState.map { !$0.mandatoryInvitees.isEmpty })
        
        // PG_CHANGED
        ElementNavigationStack {
            InviteUsersScreen(context: rateLimitedViewModel.context)
        }
        .previewDisplayName("Rate limited")
        .snapshotPreferences(expect: rateLimitedViewModel.context.$viewState.map(\.usersSection.isRateLimited))
        
        // PG_CHANGED
        ElementNavigationStack {
            InviteUsersScreen(context: localResultsOnlyViewModel.context)
        }
        .previewDisplayName("Local results only")
        .snapshotPreferences(expect: localResultsOnlyViewModel.context.$viewState.map { $0.usersSection.notice != nil })
    }
    
    static func makeViewModel(searchQuery: String? = nil,
                              // PG_CHANGED
                              searchResults: SearchUsersResults = .init(results: [.mockAlice]),
                              hasSelection: Bool = false,
                              shouldConfirm: Bool = false,
                              roomType: InviteUsersScreenRoomType? = nil,
                              isSkippable: Bool = true) -> InviteUsersScreenViewModel {
        let clientProxy = ClientProxyMock(.init())
        clientProxy.recentConversationCounterpartsReturnValue = [.mockAlice, .mockBob, .mockCharlie, .mockDan, .mockVerbose]
        
        let userDiscoveryService = UserDiscoveryServiceMock()
        userDiscoveryService.searchProfilesWithReturnValue = .success(searchResults)
        
        let viewModel = InviteUsersScreenViewModel(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                   roomType: roomType ?? .existingRoom(roomProxy: JoinedRoomProxyMock(.init(members: []))),
                                                   isSkippable: isSkippable,
                                                   userDiscoveryService: userDiscoveryService,
                                                   userIndicatorController: UserIndicatorControllerMock())
        
        if let searchQuery {
            viewModel.context.searchQuery = searchQuery
        }
        
        if hasSelection {
            viewModel.state.selectedUsers = [.mockAlice]
        }
        
        if shouldConfirm {
            viewModel.state.usersToConfirm = [.mockAlice, .mockAlice, .mockAlice, .mockAlice, .mockAlice, .mockAlice, .mockAlice, .mockAlice, .mockAlice]
            viewModel.state.bindings.presentConfirmationDialog = true
        }
        
        return viewModel
    }
}
