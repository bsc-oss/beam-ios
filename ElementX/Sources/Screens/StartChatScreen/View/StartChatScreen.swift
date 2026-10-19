//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Compound
import SwiftUI

struct StartChatScreen: View {
    @ObservedObject var context: StartChatScreenViewModel.Context
    
    var body: some View {
        Form {
            if !context.viewState.isSearching {
                mainContent
            } else {
                searchContent
            }
        }
        .compoundList()
        .track(screen: .StartChat)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(L10n.actionStartChat)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .searchController(query: $context.searchQuery,
                          placeholder: L10n.commonSearchForSomeone,
                          showsCancelButton: false,
                          disablesInteractiveDismiss: true)
        .compoundSearchField()
        .alert(item: $context.alertInfo)
        .sheet(item: $context.selectedUserToInvite) { userToInvite in
            SendInviteConfirmationView(userToInvite: userToInvite,
                                       mediaProvider: context.mediaProvider) {
                context.send(viewAction: .createDM(user: userToInvite.user))
            }
        }
        .sheet(isPresented: $context.isJoinRoomByAddressSheetPresented) {
            context.roomAddress = ""
        } content: {
            JoinRoomByAddressView(context: context)
        }
    }
    
    // MARK: - Private
    
    /// The content shown in the form when the search query is empty.
    @ViewBuilder
    private var mainContent: some View {
        createRoomSection
        // PG_CHANGED - upstream always shows this; PG gates it behind the RoomDirectorySearch flag
        if context.viewState.isRoomDirectorySearchEnabled {
            roomDirectorySearch
        }
        // PG_CHANGED
        if context.viewState.isInviteFriendsEnabled {
            inviteFriendsSection
        }
        // PG_CHANGED
        if context.viewState.isJoinRoomByAddressEnabled {
            joinRoomByAddressSection
        }
        usersSection
    }
    
    private var joinRoomByAddressSection: some View {
        Section {
            ListRow(label: .default(title: L10n.screenStartChatJoinRoomByAddressAction,
                                    icon: \.room),
                    kind: .button {
                        context.isJoinRoomByAddressSheetPresented = true
                    })
        }
    }
    
    private var roomDirectorySearch: some View {
        Section {
            ListRow(label: .default(title: L10n.screenRoomDirectorySearchTitle,
                                    icon: \.listBulleted),
                    kind: .navigationLink {
                        context.send(viewAction: .openRoomDirectorySearch)
                    })
        }
    }
    
    /// The content shown in the form when a search query has been entered.
    @ViewBuilder
    private var searchContent: some View {
        if context.viewState.hasEmptySearchResults {
            noResultsContent
        } else {
            usersSection
        }
    }
    
    private var createRoomSection: some View {
        Section {
            ListRow(label: .default(title: L10n.screenCreateRoomActionCreateRoom,
                                    icon: \.plus),
                    kind: .navigationLink { context.send(viewAction: .createRoom) })
                .accessibilityIdentifier(A11yIdentifiers.startChatScreen.createRoom)
        }
    }
    
    private var inviteFriendsSection: some View {
        Section {
            ListRow(kind: .custom {
                MatrixUserShareLink(userID: context.viewState.userID) {
                    ListRowLabel.default(title: L10n.actionInvitePeopleToApp(InfoPlistReader.main.bundleDisplayName),
                                         icon: \.shareIos)
                }
            })
            .accessibilityIdentifier(A11yIdentifiers.startChatScreen.inviteFriends)
        }
    }
    
    @ViewBuilder
    private var usersSection: some View {
        if !context.viewState.usersSection.users.isEmpty {
            Section {
                ForEach(context.viewState.usersSection.users, id: \.id) { user in
                    UserProfileListRow(user: user,
                                       membership: nil,
                                       mediaProvider: context.mediaProvider,
                                       kind: .button {
                                           context.send(viewAction: .selectUser(user))
                                       },
                                       // PG_CHANGED
                                       isFromExistingChat: context.viewState.usersSection.knownFromRoomUserIDs.contains(user.id))
                }
            } header: {
                UserDiscoverySectionHeader(section: context.viewState.usersSection) // PG_CHANGED
            }
        } else {
            Section.empty
        }
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
    
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L10n.actionCancel) {
                context.send(viewAction: .close)
            }
            .accessibilityIdentifier(A11yIdentifiers.startChatScreen.closeStartChat)
        }
    }
}

// MARK: - Previews

struct StartChatScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    // PG_CHANGED
    static let rateLimitedViewModel = makeViewModel(searchQuery: "Alice",
                                                    searchResults: .init(results: [], serverError: .rateLimited))
    static let localResultsOnlyViewModel = makeViewModel(searchQuery: "Alice",
                                                         searchResults: .init(results: [.mockAlice],
                                                                              knownFromRoomUserIDs: [UserProfile.mockAlice.id],
                                                                              serverError: .rateLimited))
    
    static var previews: some View {
        ElementNavigationStack {
            StartChatScreen(context: viewModel.context)
        }
        
        // PG_CHANGED
        ElementNavigationStack {
            StartChatScreen(context: rateLimitedViewModel.context)
        }
        .previewDisplayName("Rate limited")
        .snapshotPreferences(expect: rateLimitedViewModel.context.$viewState.map(\.usersSection.isRateLimited))
        
        // PG_CHANGED
        ElementNavigationStack {
            StartChatScreen(context: localResultsOnlyViewModel.context)
        }
        .previewDisplayName("Local results only")
        .snapshotPreferences(expect: localResultsOnlyViewModel.context.$viewState.map { $0.usersSection.notice != nil })
    }
    
    // PG_CHANGED
    static func makeViewModel(searchQuery: String = "",
                              searchResults: SearchUsersResults = .init(results: [.mockAlice])) -> StartChatScreenViewModel {
        let appSettings = AppSettings.volatile()
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: "@userid:example.com"))))
        let userDiscoveryService = UserDiscoveryServiceMock()
        userDiscoveryService.searchProfilesWithReturnValue = .success(searchResults)
        let viewModel = StartChatScreenViewModel(userSession: userSession,
                                                 analytics: AnalyticsServiceMock(.init()),
                                                 userIndicatorController: UserIndicatorControllerMock(),
                                                 userDiscoveryService: userDiscoveryService,
                                                 appSettings: appSettings)
        viewModel.state.bindings.searchQuery = searchQuery
        return viewModel
    }
}
