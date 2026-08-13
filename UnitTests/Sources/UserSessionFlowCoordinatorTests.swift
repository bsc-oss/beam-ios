//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Combine
@testable import ElementX
import Foundation
import Testing

@MainActor
struct UserSessionFlowCoordinatorTests {
    private var userSessionFlowCoordinator: UserSessionFlowCoordinator!
    private var rootCoordinator: NavigationRootCoordinator!
    private let userIndicatorController: UserIndicatorControllerMock
    private let stateMachineFactory = PublishedStateMachineFactory()
    
    private let networkReachabilitySubject: CurrentValueSubject<NetworkMonitorReachability, Never> = .init(.reachable)
    private let homeserverReachabilitySubject: CurrentValueSubject<NetworkMonitorReachability, Never> = .init(.reachable)
    private var cancellables = Set<AnyCancellable>()
    
    private var tabCoordinator: NavigationTabCoordinator<UserSessionFlowCoordinator.HomeTab>? {
        rootCoordinator?.rootCoordinator as? NavigationTabCoordinator
    }
    
    private var chatsSplitCoordinator: NavigationSplitCoordinator? {
        tabCoordinator?.tabCoordinators.first as? NavigationSplitCoordinator
    }
    
    private var detailCoordinator: CoordinatorProtocol? {
        chatsSplitCoordinator?.detailCoordinator
    }
    
    private var detailNavigationStack: NavigationStackCoordinator? {
        detailCoordinator as? NavigationStackCoordinator
    }
    
    init() async throws {
        rootCoordinator = NavigationRootCoordinator()
        
        let clientProxy = ClientProxyMock(.init(userID: "hi@bob", roomSummaryProvider: RoomSummaryProviderMock(.init(state: .loaded(.mockRooms)))))
        clientProxy.homeserverReachabilityPublisher = homeserverReachabilitySubject.asCurrentValuePublisher()
        
        let networkMonitor = NetworkMonitorMock.default
        networkMonitor.reachabilityPublisher = networkReachabilitySubject.asCurrentValuePublisher()
        let appMediator = AppMediatorMock.default
        appMediator.networkMonitor = networkMonitor
        
        userIndicatorController = UserIndicatorControllerMock.default
        let appSettings = AppSettings()

        // PG_CHANGED - Prevent onboarding from starting during tests, as the PG-added
        // attemptStartingOnboarding() Task in the .start handler would race with test
        // assertions and dismiss presented sheets.
        appSettings.hasRunIdentityConfirmationOnboarding = true
        appSettings.hasRunNotificationPermissionsOnboarding = true
        appSettings.hasRunProfileCreationOnboarding = true

        let flowParameters = CommonFlowParameters(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                  bugReportService: BugReportServiceMock(.init()),
                                                  elementCallService: ElementCallServiceMock(.init()),
                                                  timelineControllerFactory: TimelineControllerFactoryMock(.init()),
                                                  emojiProvider: EmojiProvider(appSettings: appSettings),
                                                  linkMetadataProvider: LinkMetadataProvider(),
                                                  appMediator: appMediator,
                                                  appSettings: appSettings,
                                                  appHooks: AppHooks(),
                                                  analytics: .mock(settings: appSettings),
                                                  userIndicatorController: userIndicatorController,
                                                  notificationManager: NotificationManagerMock(),
                                                  stateMachineFactory: stateMachineFactory,
                                                  pgServiceMessageService: PgServiceMessageService.mock(appSettings: appSettings)) // PG_CHANGED
        
        // PG_CHANGED - conditional pin requirement
        let appLockServiceMock = AppLockServiceMock()
        appLockServiceMock.underlyingDeviceHasLockScreen = true
        
        userSessionFlowCoordinator = UserSessionFlowCoordinator(isNewLogin: false,
                                                                navigationRootCoordinator: rootCoordinator,
                                                                appLockService: appLockServiceMock,
                                                                flowParameters: flowParameters)
        
        userSessionFlowCoordinator.start()
    }
    
    // MARK: Navigation
    
    @Test
    func initialState() {
        #expect(chatsSplitCoordinator != nil)
        #expect(detailCoordinator == nil)
    }
    
    // PG_CHANGED - verify spaces tab visibility based on spacesEnabled feature flag
    @Test
    func spacesDisabledHidesSpacesTab() {
        // spacesEnabled defaults to false, so only the chats tab should be present
        let tabTags = tabCoordinator?.tabTags ?? []
        #expect(tabTags.contains(.chats), "The chats tab should be shown")
        #expect(!tabTags.contains(.spaces), "The spaces tab should not be shown when spacesEnabled is false")
    }

    // PG_CHANGED
    @Test
    mutating func spacesEnabledShowsSpacesTab() {
        // Enable spaces and recreate the coordinator
        let appSettings = AppSettings() // PG_CHANGED - ServiceLocator removed upstream
        appSettings.spacesEnabled = true
        
        let clientProxy = ClientProxyMock(.init(userID: "hi@bob", roomSummaryProvider: RoomSummaryProviderMock(.init(state: .loaded(.mockRooms)))))
        clientProxy.homeserverReachabilityPublisher = homeserverReachabilitySubject.asCurrentValuePublisher()
        
        let networkMonitor = NetworkMonitorMock.default
        networkMonitor.reachabilityPublisher = networkReachabilitySubject.asCurrentValuePublisher()
        let appMediator = AppMediatorMock.default
        appMediator.networkMonitor = networkMonitor
        
        let flowParameters = CommonFlowParameters(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                  bugReportService: BugReportServiceMock(.init()),
                                                  elementCallService: ElementCallServiceMock(.init()),
                                                  timelineControllerFactory: TimelineControllerFactoryMock(.init()),
                                                  emojiProvider: EmojiProvider(appSettings: appSettings),
                                                  linkMetadataProvider: LinkMetadataProvider(),
                                                  appMediator: appMediator,
                                                  appSettings: appSettings,
                                                  appHooks: AppHooks(),
                                                  analytics: .mock(settings: appSettings),
                                                  userIndicatorController: userIndicatorController,
                                                  notificationManager: NotificationManagerMock(),
                                                  stateMachineFactory: stateMachineFactory,
                                                  pgServiceMessageService: PgServiceMessageService.mock(appSettings: appSettings))
        
        let appLockServiceMock = AppLockServiceMock()
        appLockServiceMock.underlyingDeviceHasLockScreen = true
        
        let coordinator = UserSessionFlowCoordinator(isNewLogin: false,
                                                     navigationRootCoordinator: rootCoordinator,
                                                     appLockService: appLockServiceMock,
                                                     flowParameters: flowParameters)
        coordinator.start()
        
        let tabTags = tabCoordinator?.tabTags ?? []
        #expect(tabTags.contains(.chats), "The chats tab should be shown")
        #expect(tabTags.contains(.spaces), "The spaces tab should be shown when spacesEnabled is true")
        
        // Clean up
        appSettings.spacesEnabled = false
    }
    
    // PG_CHANGED - verify barVisibilityOverride is driven solely by spacesEnabled
    @Test
    func spacesDisabledSetsBarVisibilityToHidden() {
        // spacesEnabled defaults to false
        let chatsDetails = tabCoordinator?.tabDetails(for: .chats)
        #expect(chatsDetails?.barVisibilityOverride == .hidden, "Tab bar should be hidden when spacesEnabled is false")
    }
    
    // PG_CHANGED
    @Test
    mutating func spacesEnabledClearsBarVisibilityOverride() {
        // The bar visibility override is driven by the coordinator's own appSettings, so the
        // coordinator must be recreated with spacesEnabled set on the settings it captures.
        let appSettings = AppSettings() // PG_CHANGED - ServiceLocator removed upstream
        appSettings.spacesEnabled = true

        let clientProxy = ClientProxyMock(.init(userID: "hi@bob", roomSummaryProvider: RoomSummaryProviderMock(.init(state: .loaded(.mockRooms)))))
        clientProxy.homeserverReachabilityPublisher = homeserverReachabilitySubject.asCurrentValuePublisher()

        let networkMonitor = NetworkMonitorMock.default
        networkMonitor.reachabilityPublisher = networkReachabilitySubject.asCurrentValuePublisher()
        let appMediator = AppMediatorMock.default
        appMediator.networkMonitor = networkMonitor

        let flowParameters = CommonFlowParameters(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                  bugReportService: BugReportServiceMock(.init()),
                                                  elementCallService: ElementCallServiceMock(.init()),
                                                  timelineControllerFactory: TimelineControllerFactoryMock(.init()),
                                                  emojiProvider: EmojiProvider(appSettings: appSettings),
                                                  linkMetadataProvider: LinkMetadataProvider(),
                                                  appMediator: appMediator,
                                                  appSettings: appSettings,
                                                  appHooks: AppHooks(),
                                                  analytics: .mock(settings: appSettings),
                                                  userIndicatorController: userIndicatorController,
                                                  notificationManager: NotificationManagerMock(),
                                                  stateMachineFactory: stateMachineFactory,
                                                  pgServiceMessageService: PgServiceMessageService.mock(appSettings: appSettings))

        let appLockServiceMock = AppLockServiceMock()
        appLockServiceMock.underlyingDeviceHasLockScreen = true

        let coordinator = UserSessionFlowCoordinator(isNewLogin: false,
                                                     navigationRootCoordinator: rootCoordinator,
                                                     appLockService: appLockServiceMock,
                                                     flowParameters: flowParameters)
        coordinator.start()

        let chatsDetails = tabCoordinator?.tabDetails(for: .chats)
        #expect(chatsDetails?.barVisibilityOverride == nil, "Tab bar visibility override should be nil when spacesEnabled is true")

        // Clean up
        appSettings.spacesEnabled = false
    }

    // PG_CHANGED - argus launcher tab tests - START

    @Test
    func argusDisabledHidesArgusTab() {
        // argusEnabled defaults to false, so the argus tab should not be present
        let tabTags = tabCoordinator?.tabTags ?? []
        #expect(!tabTags.contains(.argus), "The argus tab should not be shown when argusEnabled is false")
    }

    @Test
    func argusEnabledShowsArgusTab() {
        let appSettings = AppSettings()
        appSettings.argusEnabled = true
        defer { appSettings.argusEnabled = false } // Clean up the shared UserDefaults even if an assertion aborts the test
        let coordinator = makeStartedCoordinator(appSettings: appSettings)

        withExtendedLifetime(coordinator) {
            let tabTags = tabCoordinator?.tabTags ?? []
            #expect(tabTags.contains(.chats), "The chats tab should be shown")
            #expect(tabTags.contains(.argus), "The argus tab should be shown when argusEnabled is true")
        }
    }

    @Test
    func argusEnabledClearsBarVisibilityOverride() {
        let appSettings = AppSettings()
        appSettings.argusEnabled = true
        defer { appSettings.argusEnabled = false }
        let coordinator = makeStartedCoordinator(appSettings: appSettings)

        withExtendedLifetime(coordinator) {
            let chatsDetails = tabCoordinator?.tabDetails(for: .chats)
            #expect(chatsDetails?.barVisibilityOverride == nil, "Tab bar should be visible when argusEnabled is true (more than one tab)")
        }
    }

    @Test
    func argusTabIsLauncherThatPresentsIntoTheLauncherOverlay() {
        let appSettings = AppSettings()
        appSettings.argusEnabled = true
        defer { appSettings.argusEnabled = false }
        let coordinator = makeStartedCoordinator(appSettings: appSettings)

        withExtendedLifetime(coordinator) {
            let argusDetails = tabCoordinator?.tabDetails(for: .argus)
            #expect(argusDetails?.onSelect != nil, "The argus tab should be a launcher")
            #expect(tabCoordinator?.launcherOverlayCoordinator == nil, "Nothing should be presented before selecting the argus tab")

            argusDetails?.onSelect?()

            #expect(tabCoordinator?.launcherOverlayCoordinator is PgArgusReactNativeCoordinator, "Selecting the argus tab presents the RN flow in the launcher overlay")
            #expect(tabCoordinator?.overlayCoordinator == nil, "The argus flow must not occupy the call overlay slot")
            #expect(tabCoordinator?.selectedTab == .chats, "Selecting the argus tab does not switch the displayed tab")
        }
    }

    @Test
    func argusLauncherCoexistsWithCallOverlay() {
        let appSettings = AppSettings()
        appSettings.argusEnabled = true
        defer { appSettings.argusEnabled = false }
        let coordinator = makeStartedCoordinator(appSettings: appSettings)

        withExtendedLifetime(coordinator) {
            // Simulate an ongoing call occupying the (separate) call overlay slot…
            let callOverlay = PgArgusTabPlaceholderCoordinator()
            tabCoordinator?.setOverlayCoordinator(callOverlay)

            // …then tap the argus launcher.
            tabCoordinator?.tabDetails(for: .argus)?.onSelect?()

            // Both coexist: the call stays alive in its slot, Argus goes into the launcher slot.
            #expect(tabCoordinator?.overlayCoordinator is PgArgusTabPlaceholderCoordinator,
                    "Launching Argus must not disturb the ongoing call in the call overlay slot")
            #expect(tabCoordinator?.launcherOverlayCoordinator is PgArgusReactNativeCoordinator,
                    "Argus must be presented in the independent launcher overlay slot")
        }
    }

    @Test
    func argusDismissalClearsLauncherSlotOnly() async throws {
        let appSettings = AppSettings()
        appSettings.argusEnabled = true
        defer { appSettings.argusEnabled = false }
        let coordinator = makeStartedCoordinator(appSettings: appSettings)

        let callOverlay = PgArgusTabPlaceholderCoordinator()
        tabCoordinator?.setOverlayCoordinator(callOverlay)
        tabCoordinator?.tabDetails(for: .argus)?.onSelect?()
        #expect(tabCoordinator?.launcherOverlayCoordinator is PgArgusReactNativeCoordinator)

        // The RN bundle requests dismissal via the popToNative notification (delivered on the main queue).
        let deferred = deferFulfillment(tabCoordinator!.observe(\.launcherOverlayCoordinator)) { $0 == nil }
        NotificationCenter.default.post(name: Notification.Name("popToNative"), object: nil)
        try await deferred.fulfill()

        #expect(tabCoordinator?.launcherOverlayCoordinator == nil, "Dismissing Argus clears the launcher slot")
        #expect(tabCoordinator?.overlayCoordinator is PgArgusTabPlaceholderCoordinator, "Dismissing Argus leaves the ongoing call untouched")

        withExtendedLifetime(coordinator) { } // Keep the coordinator (and its popToNative subscription) alive across the await.
    }

    // PG_CHANGED - the server can grant argus via the profile's feature flags, even with the dev toggle off.
    @Test
    func argusServerFeatureFlagShowsArgusTab() {
        let appSettings = AppSettings()
        #expect(appSettings.argusEnabled == false, "The dev toggle must be off so we're testing the server flag alone")
        let profileSubject = CurrentValueSubject<UserProfileProxy?, Never>(UserProfileProxy(userID: "hi@bob", featureFlags: ["argus": true]))
        let coordinator = makeStartedCoordinator(appSettings: appSettings, profileSubject: profileSubject)

        withExtendedLifetime(coordinator) {
            let tabTags = tabCoordinator?.tabTags ?? []
            #expect(tabTags.contains(.argus), "The argus tab should be shown when the server grants it, even with the dev toggle off")
        }
    }

    // PG_CHANGED - server feature flags without argus (dev toggle off) keep the argus tab hidden.
    @Test
    func argusServerFeatureFlagFalseHidesArgusTab() {
        let appSettings = AppSettings()
        let profileSubject = CurrentValueSubject<UserProfileProxy?, Never>(UserProfileProxy(userID: "hi@bob", featureFlags: ["argus": false]))
        let coordinator = makeStartedCoordinator(appSettings: appSettings, profileSubject: profileSubject)

        withExtendedLifetime(coordinator) {
            let tabTags = tabCoordinator?.tabTags ?? []
            #expect(!tabTags.contains(.argus), "The argus tab should stay hidden when the server does not grant argus and the dev toggle is off")
        }
    }

    // PG_CHANGED - the argus tab appears reactively when the server grants it mid-session, without
    // disturbing the existing chats tab or the current selection.
    @Test
    mutating func argusTabAppearsReactivelyWhenServerGrantsIt() async throws {
        let appSettings = AppSettings()
        // Start with a profile that does NOT grant argus.
        let profileSubject = CurrentValueSubject<UserProfileProxy?, Never>(UserProfileProxy(userID: "hi@bob"))
        let coordinator = makeStartedCoordinator(appSettings: appSettings, profileSubject: profileSubject)

        #expect(!(tabCoordinator?.tabTags.contains(.argus) ?? true), "Argus is hidden while the server hasn't granted it")

        // The server grants argus mid-session -> the tab appears reactively.
        let deferred = deferFulfillment(tabCoordinator!.observe(\.tabTags)) { $0.contains(.argus) }
        profileSubject.send(UserProfileProxy(userID: "hi@bob", featureFlags: ["argus": true]))
        try await deferred.fulfill()

        #expect(tabCoordinator?.tabTags.contains(.chats) == true, "The chats tab is preserved when argus appears")
        #expect(tabCoordinator?.selectedTab == .chats, "The selection is preserved when argus appears")

        withExtendedLifetime(coordinator) { } // Keep the coordinator (and its profile subscription) alive across the await.
    }

    // PG_CHANGED - toggling the dev argus flag updates the tab live (no app restart).
    @Test
    mutating func argusDevToggleUpdatesTabReactively() async throws {
        let appSettings = AppSettings()
        appSettings.argusEnabled = false
        defer { appSettings.argusEnabled = false }
        let coordinator = makeStartedCoordinator(appSettings: appSettings)

        #expect(!(tabCoordinator?.tabTags.contains(.argus) ?? true), "Argus is hidden while the dev flag is off")

        // Enabling the dev flag adds the tab live.
        let deferredShow = deferFulfillment(tabCoordinator!.observe(\.tabTags)) { $0.contains(.argus) }
        appSettings.argusEnabled = true
        try await deferredShow.fulfill()

        // Disabling it removes the tab live, without disturbing chats.
        let deferredHide = deferFulfillment(tabCoordinator!.observe(\.tabTags)) { !$0.contains(.argus) }
        appSettings.argusEnabled = false
        try await deferredHide.fulfill()
        #expect(tabCoordinator?.tabTags.contains(.chats) == true, "The chats tab is preserved throughout")

        withExtendedLifetime(coordinator) { } // Keep the coordinator (and its subscriptions) alive across the awaits.
    }

    // PG_CHANGED - revoking argus while the RN flow is presented dismisses it: the server blocks the
    // argus endpoints once the flag is off, so the RN session can't succeed anymore and keeping it up
    // with a dead bridge would only produce timeouts.
    @Test
    func argusRevocationWhileRNFlowIsPresentedDismissesIt() async throws {
        let appSettings = AppSettings()
        appSettings.argusEnabled = true
        defer { appSettings.argusEnabled = false }
        let coordinator = makeStartedCoordinator(appSettings: appSettings)

        tabCoordinator?.tabDetails(for: .argus)?.onSelect?()
        #expect(tabCoordinator?.launcherOverlayCoordinator is PgArgusReactNativeCoordinator, "The RN flow should be presented before the revocation")

        let deferred = deferFulfillment(tabCoordinator!.observe(\.tabTags)) { !$0.contains(.argus) }
        appSettings.argusEnabled = false
        try await deferred.fulfill()

        #expect(tabCoordinator?.launcherOverlayCoordinator == nil, "Revoking argus dismisses the presented RN flow")
        #expect(tabCoordinator?.tabTags.contains(.chats) == true, "The chats tab is preserved through the revocation")
        #expect(userIndicatorController.submitIndicatorDelayReceivedArguments?.indicator.title == L10n.pgArgusNoLongerAvailable,
                "A toast explains why the RN flow was dismissed")

        withExtendedLifetime(coordinator) { } // Keep the coordinator (and its subscriptions) alive across the await.
    }

    // PG_CHANGED - argus launcher tab tests - END

    // PG_CHANGED - builds a started coordinator capturing the given appSettings (for flag-dependent tests).
    // When `profileSubject` is provided it drives the logged-in user's profile publisher, letting tests
    // control the server-provided argus feature flag (and emit updates to exercise the reactive path).
    private func makeStartedCoordinator(appSettings: AppSettings,
                                        profileSubject: CurrentValueSubject<UserProfileProxy?, Never>? = nil) -> UserSessionFlowCoordinator {
        let clientProxy = ClientProxyMock(.init(userID: "hi@bob", roomSummaryProvider: RoomSummaryProviderMock(.init(state: .loaded(.mockRooms)))))
        clientProxy.homeserverReachabilityPublisher = homeserverReachabilitySubject.asCurrentValuePublisher()
        if let profileSubject {
            clientProxy.userProfileProxyPublisher = profileSubject.asCurrentValuePublisher()
        }

        let networkMonitor = NetworkMonitorMock.default
        networkMonitor.reachabilityPublisher = networkReachabilitySubject.asCurrentValuePublisher()
        let appMediator = AppMediatorMock.default
        appMediator.networkMonitor = networkMonitor

        let flowParameters = CommonFlowParameters(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                                  bugReportService: BugReportServiceMock(.init()),
                                                  elementCallService: ElementCallServiceMock(.init()),
                                                  timelineControllerFactory: TimelineControllerFactoryMock(.init()),
                                                  emojiProvider: EmojiProvider(appSettings: appSettings),
                                                  linkMetadataProvider: LinkMetadataProvider(),
                                                  appMediator: appMediator,
                                                  appSettings: appSettings,
                                                  appHooks: AppHooks(),
                                                  analytics: .mock(settings: appSettings),
                                                  userIndicatorController: userIndicatorController,
                                                  notificationManager: NotificationManagerMock(),
                                                  stateMachineFactory: stateMachineFactory,
                                                  pgServiceMessageService: PgServiceMessageService.mock(appSettings: appSettings))

        let appLockServiceMock = AppLockServiceMock()
        appLockServiceMock.underlyingDeviceHasLockScreen = true

        let coordinator = UserSessionFlowCoordinator(isNewLogin: false,
                                                     navigationRootCoordinator: rootCoordinator,
                                                     appLockService: appLockServiceMock,
                                                     flowParameters: flowParameters)
        coordinator.start()
        return coordinator
    }

    @Test
    mutating func settingsPresentation() async throws {
        try await process(route: .settings, expectedUserSessionState: .settingsScreen)
        #expect((tabCoordinator?.sheetCoordinator as? NavigationStackCoordinator)?.rootCoordinator is SettingsScreenCoordinator)
    }
    
    @Test
    mutating func roomPresentation() async throws {
        try await process(route: .room(roomID: "1", via: []), expectedChatsState: .roomList(detailState: .room(roomID: "1")))
        #expect(detailNavigationStack?.rootCoordinator is RoomScreenCoordinator)
        #expect(detailCoordinator != nil)
    }
    
    @Test
    mutating func roomPresentationClearsSettings() async throws {
        try await process(route: .settings, expectedUserSessionState: .settingsScreen)
        #expect((tabCoordinator?.sheetCoordinator as? NavigationStackCoordinator)?.rootCoordinator is SettingsScreenCoordinator)
        #expect(detailCoordinator == nil)
        
        try await process(route: .room(roomID: "1", via: []), expectedChatsState: .roomList(detailState: .room(roomID: "1")))
        #expect(tabCoordinator?.sheetCoordinator == nil)
        #expect(detailNavigationStack?.rootCoordinator is RoomScreenCoordinator)
        #expect(detailCoordinator != nil)
    }
    
    @Test
    mutating func childRoomPresentation() async throws {
        try await process(route: .room(roomID: "1", via: []), expectedChatsState: .roomList(detailState: .room(roomID: "1")))
        let detailNavigationStack = try #require(detailNavigationStack, "There must be a navigation stack.")
        #expect(detailNavigationStack.rootCoordinator is RoomScreenCoordinator)
        #expect(detailCoordinator != nil)
        
        let deferred = deferFulfillment(detailNavigationStack.observe(\.stackCoordinators.count)) { $0 == 1 }
        try await process(route: .childRoom(roomID: "2", via: []))
        try await deferred.fulfill()
        #expect(detailNavigationStack.rootCoordinator is RoomScreenCoordinator)
        #expect(detailCoordinator != nil)
        #expect(detailNavigationStack.stackCoordinators.count == 1)
        #expect(detailNavigationStack.stackCoordinators.first is RoomScreenCoordinator)
    }
    
    @Test
    mutating func shareMediaRouteWithoutRoom() async throws {
        try await process(route: .settings, expectedUserSessionState: .settingsScreen)
        #expect((tabCoordinator?.sheetCoordinator as? NavigationStackCoordinator)?.rootCoordinator is SettingsScreenCoordinator)
        #expect(chatsSplitCoordinator?.sheetCoordinator == nil)
        
        let sharePayload: ShareExtensionPayload = .mediaFiles(roomID: nil, mediaFiles: [.init(url: .picturesDirectory, suggestedName: nil)])
        try await process(route: .share(sharePayload),
                          expectedUserSessionState: .tabBar,
                          expectedChatsState: .shareExtensionRoomList(sharePayload: sharePayload))
        #expect(tabCoordinator?.sheetCoordinator == nil)
        #expect((chatsSplitCoordinator?.sheetCoordinator as? NavigationStackCoordinator)?.rootCoordinator is RoomSelectionScreenCoordinator)
    }
    
    @Test
    mutating func shareMediaRouteWithRoom() async throws {
        try await process(route: .event(eventID: "1", roomID: "1", via: []), expectedChatsState: .roomList(detailState: .room(roomID: "1")))
        #expect(detailNavigationStack?.rootCoordinator is RoomScreenCoordinator)
        #expect(tabCoordinator?.sheetCoordinator == nil)
        #expect(chatsSplitCoordinator?.sheetCoordinator == nil)
        
        let sharePayload: ShareExtensionPayload = .mediaFiles(roomID: "2", mediaFiles: [.init(url: .picturesDirectory, suggestedName: nil)])
        try await process(route: .share(sharePayload),
                          expectedChatsState: .roomList(detailState: .room(roomID: "2")))
        
        #expect(detailNavigationStack?.rootCoordinator is RoomScreenCoordinator)
        #expect(tabCoordinator?.sheetCoordinator == nil)
        #expect((chatsSplitCoordinator?.sheetCoordinator as? NavigationStackCoordinator)?.rootCoordinator is MediaUploadPreviewScreenCoordinator)
    }
    
    @Test
    mutating func shareTextRouteWithoutRoom() async throws {
        try await process(route: .settings, expectedUserSessionState: .settingsScreen)
        #expect((tabCoordinator?.sheetCoordinator as? NavigationStackCoordinator)?.rootCoordinator is SettingsScreenCoordinator)
        #expect(chatsSplitCoordinator?.sheetCoordinator == nil)
        
        let sharePayload: ShareExtensionPayload = .text(roomID: nil, text: "Important Text")
        try await process(route: .share(sharePayload),
                          expectedUserSessionState: .tabBar,
                          expectedChatsState: .shareExtensionRoomList(sharePayload: sharePayload))
        #expect(tabCoordinator?.sheetCoordinator == nil)
        #expect((chatsSplitCoordinator?.sheetCoordinator as? NavigationStackCoordinator)?.rootCoordinator is RoomSelectionScreenCoordinator)
    }
    
    @Test
    mutating func shareTextRouteWithRoom() async throws {
        try await process(route: .event(eventID: "1", roomID: "1", via: []), expectedChatsState: .roomList(detailState: .room(roomID: "1")))
        #expect(detailNavigationStack?.rootCoordinator is RoomScreenCoordinator)
        #expect(tabCoordinator?.sheetCoordinator == nil)
        #expect(chatsSplitCoordinator?.sheetCoordinator == nil)
        
        let sharePayload: ShareExtensionPayload = .text(roomID: "2", text: "Important text")
        try await process(route: .share(sharePayload),
                          expectedChatsState: .roomList(detailState: .room(roomID: "2")))
        
        #expect(detailNavigationStack?.rootCoordinator is RoomScreenCoordinator)
        #expect(tabCoordinator?.sheetCoordinator == nil)
        #expect(chatsSplitCoordinator?.sheetCoordinator == nil, "The media upload sheet shouldn't be shown when sharing text.")
    }
    
    // MARK: Indicators
    
    @Test
    func reachabilityIndicators() async throws {
        // Given a flow in its initial state.
        try await Task.sleep(for: .milliseconds(100))
        
        // Then no reachability indicators should be shown.
        #expect(!userIndicatorController.submitIndicatorDelayCalled)
        #expect(retractReachabilityIndicatorCallsCount == 1) // The initial state removes the indicator.
        
        // When the homeserver becomes unreachable.
        homeserverReachabilitySubject.send(.unreachable)
        try await Task.sleep(for: .milliseconds(100))
        
        // Then a server unreachable indicator should be shown.
        #expect(userIndicatorController.submitIndicatorDelayCallsCount == 1)
        #expect(userIndicatorController.submitIndicatorDelayReceivedArguments?.indicator.title == L10n.commonServerUnreachable)
        #expect(retractReachabilityIndicatorCallsCount == 1)
        
        // When the network also becomes unreachable.
        networkReachabilitySubject.send(.unreachable)
        try await Task.sleep(for: .milliseconds(100))
        
        // Then the server unreachable indicator should be replaced with an offline indicator.
        #expect(userIndicatorController.submitIndicatorDelayCallsCount == 2)
        #expect(userIndicatorController.submitIndicatorDelayReceivedArguments?.indicator.title == L10n.commonOffline)
        #expect(retractReachabilityIndicatorCallsCount == 1)
        
        // When the homeserver becomes reachable again.
        homeserverReachabilitySubject.send(.reachable)
        try await Task.sleep(for: .milliseconds(100))
        
        // Then there should still be an offline indicator (as we don't yet support air-gapped servers on iOS).
        #expect(userIndicatorController.submitIndicatorDelayCallsCount == 3)
        #expect(userIndicatorController.submitIndicatorDelayReceivedArguments?.indicator.title == L10n.commonOffline)
        #expect(retractReachabilityIndicatorCallsCount == 1)
        
        // When the network becomes reachable again.
        networkReachabilitySubject.send(.reachable)
        try await Task.sleep(for: .milliseconds(100))
        
        // Then the indicator should be hidden now as everything is back to normal
        #expect(userIndicatorController.submitIndicatorDelayCallsCount == 3)
        #expect(retractReachabilityIndicatorCallsCount == 2)
    }
    
    // MARK: - Helpers
    
    private mutating func process(route: AppRoute,
                                  expectedUserSessionState: UserSessionFlowCoordinator.State? = nil,
                                  expectedChatsState: ChatsTabFlowCoordinatorStateMachine.State? = nil) async throws {
        let deferredUserSession: DeferredFulfillment<UserSessionFlowCoordinator.State>? = if let expectedUserSessionState {
            deferFulfillment(stateMachineFactory.userSessionFlowStatePublisher.delay(for: .milliseconds(100), scheduler: DispatchQueue.main)) {
                $0 == expectedUserSessionState
            }
        } else {
            nil
        }
        
        let deferredChatsState: DeferredFulfillment<ChatsTabFlowCoordinatorStateMachine.State>? = if let expectedChatsState {
            deferFulfillment(stateMachineFactory.chatsTabFlowStatePublisher.delay(for: .milliseconds(100), scheduler: DispatchQueue.main)) {
                $0 == expectedChatsState
            }
        } else {
            nil
        }
        
        userSessionFlowCoordinator.handleAppRoute(route, animated: true)
        try await deferredUserSession?.fulfill()
        try await deferredChatsState?.fulfill()
    }
    
    /// Other services retract indicators, so this filters based on the reachability ID.
    private var retractReachabilityIndicatorCallsCount: Int {
        userIndicatorController
            .retractIndicatorWithIdReceivedInvocations
            .filter { $0 == "io.element.elementx.reachability.notification" }
            .count
    }
}
