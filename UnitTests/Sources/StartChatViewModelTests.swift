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

@testable import ElementX
import Testing

@MainActor
struct StartChatScreenViewModelTests {
    private var viewModel: StartChatScreenViewModelProtocol!
    private var clientProxy: ClientProxyMock!
    private var userDiscoveryService: UserDiscoveryServiceMock!
    
    private var context: StartChatScreenViewModel.Context {
        viewModel.context
    }
    
    init() {
        clientProxy = .init(.init(userID: ""))
        userDiscoveryService = UserDiscoveryServiceMock()
        userDiscoveryService.searchProfilesWithReturnValue = .success(.init(results: [])) // PG_CHANGED
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        viewModel = StartChatScreenViewModel(userSession: userSession,
                                             analytics: AnalyticsServiceMock(.init()),
                                             userIndicatorController: UserIndicatorControllerMock(),
                                             userDiscoveryService: userDiscoveryService,
                                             appSettings: .volatile()) // PG_CHANGED
    }
    
    @Test
    mutating func queryShowingNoResults() async throws {
        await search(query: "A")
        #expect(context.viewState.usersSection.type == .suggestions)
        
        // PG_CHANGED - searchQuery based on 2 chars is now a valid search (upstream requires 3).
        // Using deferFulfillment to explicitly wait for search results, as nextValue may return
        // before the async search task completes.
        let deferred = deferFulfillment(context.$viewState) { $0.usersSection.type == .searchResult }
        viewModel.context.searchQuery = "AA"
        try await deferred.fulfill()
        assertSearchResults(toBe: 0)
        
        #expect(userDiscoveryService.searchProfilesWithCalled)
    }
    
    // PG_CHANGED
    @Test
    func rateLimitedSearchShowsTheRefusal() async throws {
        userDiscoveryService.searchProfilesWithReturnValue = .success(.init(results: [], serverError: .rateLimited))
        
        let deferred = deferFulfillment(context.$viewState) { $0.usersSection.type == .searchResult }
        context.searchQuery = "AA"
        try await deferred.fulfill()
        
        assertSearchResults(toBe: 0)
        #expect(context.viewState.usersSection.isRateLimited)
        // Nothing to show, so an error rather than a notice.
        #expect(context.viewState.usersSection.notice == nil)
    }
    
    // PG_CHANGED
    @Test
    func localResultsOnlySearchShowsNotice() async throws {
        userDiscoveryService.searchProfilesWithReturnValue = .success(.init(results: [.mockAlice],
                                                                            knownFromRoomUserIDs: [UserProfile.mockAlice.id],
                                                                            serverError: .rateLimited))
        
        let deferred = deferFulfillment(context.$viewState) { $0.usersSection.type == .searchResult }
        context.searchQuery = "AA"
        try await deferred.fulfill()
        
        assertSearchResults(toBe: 1)
        #expect(context.viewState.usersSection.notice == L10n.pgCommonSearchLocalResultsOnlyRateLimited)
        #expect(context.viewState.usersSection.knownFromRoomUserIDs == [UserProfile.mockAlice.id])
    }
    
    @Test
    func joinRoomByAddress() async throws {
        clientProxy.resolveRoomAliasReturnValue = .success(.init(roomId: "id", servers: []))
        
        let deferredViewState = deferFulfillment(viewModel.context.$viewState) { viewState in
            viewState.joinByAddressState == .addressFound(address: "#room:example.com", roomID: "id")
        }
        viewModel.context.roomAddress = "#room:example.com"
        try await deferredViewState.fulfill()
        
        let deferredAction = deferFulfillment(viewModel.actions) { action in
            action == .showRoom(roomID: "id")
        }
        context.send(viewAction: .joinRoomByAddress)
        try await deferredAction.fulfill()
    }
    
    @Test
    func joinRoomByAddressFailsBecauseInvalid() async throws {
        let deferred = deferFulfillment(viewModel.context.$viewState) { viewState in
            viewState.joinByAddressState == .invalidAddress
        }
        viewModel.context.roomAddress = ":"
        context.send(viewAction: .joinRoomByAddress)
        try await deferred.fulfill()
    }
    
    @Test
    func joinRoomByAddressFailsBecauseNotFound() async throws {
        clientProxy.resolveRoomAliasReturnValue = .failure(.failedResolvingRoomAlias)
        
        let deferred = deferFulfillment(viewModel.context.$viewState) { viewState in
            viewState.joinByAddressState == .addressNotFound
        }
        viewModel.context.roomAddress = "#room:example.com"
        context.send(viewAction: .joinRoomByAddress)
        try await deferred.fulfill()
    }
    
    // PG_CHANGED
    @Test
    func createDirectRoomSuccess() async throws {
        let expectedRoomID = "!dm:server"
        clientProxy.createDirectRoomWithExpectedRoomNameReturnValue = .success(expectedRoomID)
        
        let user = UserProfile(userID: "@alice:example.com",
                               displayName: "Alice",
                               avatarURL: nil,
                               email: "alice@example.com")
        
        let deferredAction = deferFulfillment(viewModel.actions) { action in
            action == .showRoom(roomID: expectedRoomID)
        }
        
        context.send(viewAction: .createDM(user: user))
        try await deferredAction.fulfill()
        
        #expect(clientProxy.createDirectRoomWithExpectedRoomNameCallsCount == 1)
        #expect(clientProxy.createDirectRoomWithExpectedRoomNameReceivedArguments?.userID == user.userID)
        #expect(clientProxy.createDirectRoomWithExpectedRoomNameReceivedArguments?.expectedRoomName == user.displayName)
    }
    
    // MARK: - History Sharing
    
    @Test
    func inviteConfirmationFetchesIdentity() async throws {
        clientProxy.directRoomForUserIDReturnValue = .success(nil)
        clientProxy.userIdentityForFallBackToServerReturnValue = .success(UserIdentityProxyMock(.init(verificationState: .notVerified)))
        
        // User identity becomes known, i.e. not unknown
        let deferred = deferFulfillment(viewModel.context.$viewState.compactMap(\.bindings.selectedUserToInvite)) {
            !$0.isUnknown
        }
        context.send(viewAction: .selectUser(.mockBob))
        try await deferred.fulfill()
        
        #expect(clientProxy.userIdentityForFallBackToServerCalled)
    }
    
    @Test
    func inviteConfirmationFallsBackToUnknownIdentityOnFailure() async throws {
        clientProxy.directRoomForUserIDReturnValue = .success(nil)
        clientProxy.userIdentityForFallBackToServerReturnValue = .failure(.forbiddenAccess)
        
        // User identity never becomes known, i.e. is never not unknown
        let deferred = deferFailure(viewModel.context.$viewState.compactMap(\.bindings.selectedUserToInvite), timeout: .seconds(5)) {
            !$0.isUnknown
        }
        context.send(viewAction: .selectUser(.mockBob))
        try await deferred.fulfill()
        
        #expect(clientProxy.userIdentityForFallBackToServerCalled)
    }
    
    // MARK: - Private
    
    private func assertSearchResults(toBe count: Int) {
        #expect(count >= 0)
        #expect(context.viewState.usersSection.type == .searchResult)
        #expect(context.viewState.usersSection.users.count == count)
        #expect(context.viewState.hasEmptySearchResults == (count == 0))
    }
    
    @discardableResult
    private mutating func search(query: String) async -> StartChatScreenViewState? {
        viewModel.context.searchQuery = query
        return await context.$viewState.nextValue
    }
}
