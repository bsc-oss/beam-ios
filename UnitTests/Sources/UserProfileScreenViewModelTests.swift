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
struct UserProfileScreenViewModelTests {
    @Test
    func initialState() async throws {
        let appSettings = AppSettings()
        let analytics = AnalyticsService.mock(settings: appSettings)
        let userIndicatorController = UserIndicatorControllerMock.default

        let profile = UserProfileProxy(userID: "@alice:matrix.org", displayName: "Alice", avatarURL: .mockMXCAvatar)
        let clientProxy = ClientProxyMock(.init())
        clientProxy.profileForReturnValue = .success(profile)
        
        let viewModel = UserProfileScreenViewModel(userID: profile.userID,
                                                   isPresentedModally: false,
                                                   userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                   userIndicatorController: userIndicatorController,
                                                   analytics: analytics,
                                                   appSettings: appSettings)
        let context = viewModel.context
        
        let waitForMemberToLoad = deferFulfillment(context.observe(\.viewState.userProfile)) { $0 != nil }
        try await waitForMemberToLoad.fulfill()
        
        #expect(!context.viewState.isOwnUser)
        #expect(context.viewState.userProfile == profile)
        #expect(context.viewState.permalink != nil)
    }
    
    @Test
    func initialStateAccountOwner() async throws {
        let appSettings = AppSettings()
        let analytics = AnalyticsService.mock(settings: appSettings)
        let userIndicatorController = UserIndicatorControllerMock.default

        let profile = UserProfileProxy(userID: RoomMemberProxyMock.mockMe.userID, displayName: "Me", avatarURL: .mockMXCAvatar)
        let clientProxy = ClientProxyMock(.init())
        clientProxy.profileForReturnValue = .success(profile)
        
        let viewModel = UserProfileScreenViewModel(userID: profile.userID,
                                                   isPresentedModally: false,
                                                   userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                   userIndicatorController: userIndicatorController,
                                                   analytics: analytics,
                                                   appSettings: appSettings)
        let context = viewModel.context
        
        let waitForMemberToLoad = deferFulfillment(context.observe(\.viewState.userProfile)) { $0 != nil }
        try await waitForMemberToLoad.fulfill()
        
        #expect(context.viewState.isOwnUser)
        #expect(context.viewState.userProfile == profile)
        #expect(context.viewState.permalink != nil)
    }

    // PG_CHANGED
    @Test
    func createDirectChatSuccess() async throws {
        let expectedRoomID = "!dm:server"
        let profile = UserProfileProxy(userID: "@alice:matrix.org",
                                       displayName: "Alice",
                                       avatarURL: nil,
                                       email: "alice@example.com")
        let appSettings = AppSettings()
        let clientProxy = ClientProxyMock(.init())
        clientProxy.profileForReturnValue = .success(profile)
        clientProxy.createDirectRoomWithExpectedRoomNameReturnValue = .success(expectedRoomID)

        let viewModel = UserProfileScreenViewModel(userID: profile.userID,
                                                   isPresentedModally: false,
                                                   userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                   userIndicatorController: UserIndicatorControllerMock.default,
                                                   analytics: .mock(settings: appSettings),
                                                   appSettings: appSettings)
        let context = viewModel.context

        let waitForProfile = deferFulfillment(context.observe(\.viewState.userProfile)) { $0 != nil }
        try await waitForProfile.fulfill()

        let deferredAction = deferFulfillment(viewModel.actionsPublisher) { action in
            if case let .openDirectChat(roomID) = action {
                return roomID == expectedRoomID
            }
            return false
        }

        context.send(viewAction: .createDirectChat)
        try await deferredAction.fulfill()

        #expect(clientProxy.createDirectRoomWithExpectedRoomNameCallsCount == 1)
        #expect(clientProxy.createDirectRoomWithExpectedRoomNameReceivedArguments?.userID == profile.userID)
        #expect(clientProxy.createDirectRoomWithExpectedRoomNameReceivedArguments?.expectedRoomName == profile.displayName)
    }

    @Test
    func startingDmWithUnknownUserFetchesIdentity() async throws {
        let appSettings = AppSettings()
        let analytics = AnalyticsService.mock(settings: appSettings)
        let userIndicatorController = UserIndicatorControllerMock.default

        let profile = UserProfileProxy.mockAlice

        let clientProxy = ClientProxyMock(.init())
        clientProxy.directRoomForUserIDReturnValue = .success(nil)
        clientProxy.userIdentityForFallBackToServerReturnValue = .success(nil)

        let viewModel = UserProfileScreenViewModel(userID: profile.userID,
                                                   isPresentedModally: false,
                                                   userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                   userIndicatorController: userIndicatorController,
                                                   analytics: analytics,
                                                   appSettings: appSettings)

        let context = viewModel.context

        let waitForMemberToLoad = deferFulfillment(context.observe(\.viewState.userProfile)) { $0 != nil }
        try await waitForMemberToLoad.fulfill()

        let deferred = deferFulfillment(context.observe(\.viewState.bindings).compactMap(\.inviteConfirmationUser), timeout: .seconds(5)) { $0.isUnknown }

        context.send(viewAction: .openDirectChat)
        try await deferred.fulfill()
    }
}
