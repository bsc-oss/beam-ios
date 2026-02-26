//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import XCTest

@testable import ElementX

@MainActor
class StartChatScreenViewModelTests: XCTestCase {
    var viewModel: StartChatScreenViewModelProtocol!
    var clientProxy: ClientProxyMock!
    var userDiscoveryService: UserDiscoveryServiceMock!
    
    var context: StartChatScreenViewModel.Context {
        viewModel.context
    }
    
    override func setUpWithError() throws {
        clientProxy = .init(.init(userID: ""))
        userDiscoveryService = UserDiscoveryServiceMock()
        userDiscoveryService.searchProfilesWithReturnValue = .success([])
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        viewModel = StartChatScreenViewModel(userSession: userSession,
                                             analytics: ServiceLocator.shared.analytics,
                                             userIndicatorController: UserIndicatorControllerMock(),
                                             userDiscoveryService: userDiscoveryService,
                                             appSettings: ServiceLocator.shared.settings)
    }
    
    func testQueryShowingNoResults() async throws {
        await search(query: "A")
        XCTAssertEqual(context.viewState.usersSection.type, .suggestions)
        
        // PG_CHANGED - searchQuery based on 2 chars is now a valid search.
//        await search(query: "AA")
//        XCTAssertEqual(context.viewState.usersSection.type, .suggestions)
//        XCTAssertFalse(userDiscoveryService.searchProfilesWithCalled)

        context.searchQuery = "AAA"
        let deferred = deferFulfillment(context.$viewState) { state in
            state.usersSection.type == .searchResult && state.usersSection.users.isEmpty
        }
        try await deferred.fulfill()
        assertSearchResults(toBe: 0)
        
        XCTAssertTrue(userDiscoveryService.searchProfilesWithCalled)
    }
    
    func testJoinRoomByAddress() async throws {
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
    
    func testJoinRoomByAddressFailsBecauseInvalid() async throws {
        let deferred = deferFulfillment(viewModel.context.$viewState) { viewState in
            viewState.joinByAddressState == .invalidAddress
        }
        viewModel.context.roomAddress = ":"
        context.send(viewAction: .joinRoomByAddress)
        try await deferred.fulfill()
    }
    
    func testJoinRoomByAddressFailsBecauseNotFound() async throws {
        clientProxy.resolveRoomAliasReturnValue = .failure(.failedResolvingRoomAlias)
        
        let deferred = deferFulfillment(viewModel.context.$viewState) { viewState in
            viewState.joinByAddressState == .addressNotFound
        }
        viewModel.context.roomAddress = "#room:example.com"
        context.send(viewAction: .joinRoomByAddress)
        try await deferred.fulfill()
    }
    
    // PG_CHANGED
    func testCreateDirectRoomSuccess() async throws {
        let expectedRoomID = "!dm:server"
        clientProxy.createDirectRoomWithExpectedRoomNameReturnValue = .success(expectedRoomID)

        let user = UserProfileProxy(userID: "@alice:example.com",
                                    displayName: "Alice",
                                    avatarURL: nil,
                                    email: "alice@example.com")

        let deferredAction = deferFulfillment(viewModel.actions) { action in
            action == .showRoom(roomID: expectedRoomID)
        }

        context.send(viewAction: .createDM(user: user))
        try await deferredAction.fulfill()

        XCTAssertEqual(clientProxy.createDirectRoomWithExpectedRoomNameCallsCount, 1)
        XCTAssertEqual(clientProxy.createDirectRoomWithExpectedRoomNameReceivedArguments?.userID, user.userID)
        XCTAssertEqual(clientProxy.createDirectRoomWithExpectedRoomNameReceivedArguments?.expectedRoomName, user.displayName)
    }
    
    // MARK: - Private
    
    private func assertSearchResults(toBe count: Int) {
        XCTAssertTrue(count >= 0)
        XCTAssertEqual(context.viewState.usersSection.type, .searchResult)
        XCTAssertEqual(context.viewState.usersSection.users.count, count)
        XCTAssertEqual(context.viewState.hasEmptySearchResults, count == 0)
    }
    
    @discardableResult
    private func search(query: String) async -> StartChatScreenViewState? {
        viewModel.context.searchQuery = query
        return await context.$viewState.nextValue
    }
}
