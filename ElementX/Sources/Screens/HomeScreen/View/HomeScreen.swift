//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-09-29

import Combine
import Compound
import SentrySwiftUI
import SwiftUI

struct HomeScreen: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    
    @State private var scrollViewAdapter = ScrollViewAdapter()
    
    @Namespace private var navigationTransitionNamespace
    private enum NavigationTransitionSourceID {
        case spaceFilters
    }
    
    var body: some View {
        HomeScreenContent(context: context, scrollViewAdapter: scrollViewAdapter)
            .alert(item: $context.alertInfo)
            .alert(item: $context.leaveRoomAlertItem,
                   actions: leaveRoomAlertActions,
                   message: leaveRoomAlertMessage)
            .navigationTitle(title)
            .toolbar { toolbar }
            .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
            .track(screen: .Home)
            .toolbarBloom(hasSearchBar: true)
            .sentryTrace("\(Self.self)")
            .sheet(item: $context.spaceFiltersViewModel) { vm in
                ChatsSpaceFiltersScreen(context: vm.context)
                    .navigationTransition(.zoom(sourceID: NavigationTransitionSourceID.spaceFilters,
                                                in: navigationTransitionNamespace))
            }
            // PG_CHANGED - TEMPORARY: unverified devices warning, to be removed once MSC4153 (exclude insecure devices) is adopted.
            .onAppear { context.send(viewAction: .unverifiedDevicesVisibilityChanged(isVisible: true)) }
            .onDisappear { context.send(viewAction: .unverifiedDevicesVisibilityChanged(isVisible: false)) }
    }
    
    // MARK: - Private
    
    private var title: String {
        if let selectedSpace = context.viewState.selectedSpaceFilter {
            selectedSpace.room.name
        } else {
            L10n.screenRoomlistMainSpaceTitle
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            settingsButton
                .buttonStyle(.borderless)
        }
        
        ToolbarItem(placement: .primaryAction) {
            if #available(iOS 26, *) {
                newRoomButton
            } else {
                newRoomButton
                    .buttonStyle(.compound(.super, size: .toolbarIcon))
            }
        }
        
        if context.viewState.shouldShowSpaceFilters {
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            
            ToolbarItem(placement: .primaryAction) {
                SpaceFiltersButton(selected: context.viewState.selectedSpaceFilter != nil) {
                    context.send(viewAction: .spaceFilters)
                }
                .matchedTransitionSource(id: NavigationTransitionSourceID.spaceFilters,
                                         in: navigationTransitionNamespace)
            }
        }
    }
    
    private var settingsButton: some View {
        Button {
            context.send(viewAction: .showSettings)
        } label: {
            AvatarSettingsButtonLabel(userProfile: context.viewState.userProfile,
                                      mediaProvider: context.mediaProvider)
        }
        .accessibilityLabel(L10n.commonSettings)
        .accessibilityIdentifier(A11yIdentifiers.homeScreen.userAvatar)
    }
    
    @ViewBuilder
    private var newRoomButton: some View {
        switch context.viewState.roomListMode {
        case .empty, .rooms:
            Button {
                context.send(viewAction: .startChat)
            } label: {
                CompoundIcon(\.plus)
            }
            .accessibilityLabel(L10n.actionStartChat)
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.startChat)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func leaveRoomAlertActions(_ item: LeaveRoomAlertItem) -> some View {
        Button(item.cancelTitle, role: .cancel) { }
        Button(item.confirmationTitle, role: .destructive) {
            context.send(viewAction: .confirmLeaveRoom(roomIdentifier: item.roomID))
        }
    }
    
    private func leaveRoomAlertMessage(_ item: LeaveRoomAlertItem) -> some View {
        Text(item.subtitle)
    }
    
    private struct SpaceFiltersButton: View {
        @Environment(\.isInSidebar) private var isInSidebar
        
        var selected = false
        var action: () -> Void
        
        /// Design prefers the custom style over the system's styling of a Toggle within a toolbar,
        /// however Glass isn't supported for toolbar buttons in the sidebar on iPadOS 26 (likely due
        /// to glass on glass being discouraged by Apple), so we need to handle our styling accordingly.
        var shouldUseGlassButtonStyle: Bool {
            !isInSidebar
        }
        
        var body: some View {
            if #available(iOS 26, *), shouldUseGlassButtonStyle {
                if selected {
                    content
                        .backportButtonStyleGlassProminent()
                        .tint(.compound.bgActionPrimaryRest)
                } else {
                    content
                }
            } else {
                if selected {
                    content
                        .buttonStyle(.compound(.primary, size: .toolbarIcon))
                } else {
                    content
                        .buttonStyle(.compound(.tertiary, size: .toolbarIcon))
                }
            }
        }
        
        private var content: some View {
            Button {
                action()
            } label: {
                CompoundIcon(\.filter)
            }
            .accessibilityLabel(L10n.screenRoomlistYourSpaces)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(A11yIdentifiers.homeScreen.spaceFilters)
        }
    }
}

// MARK: - Previews

struct HomeScreen_Previews: PreviewProvider, TestablePreview {
    static let loadingViewModel = viewModel(.skeletons)
    static let emptyViewModel = viewModel(.empty)
    static let loadedViewModel = viewModel(.rooms)
    // PG_CHANGED - TEMPORARY: unverified devices warning, to be removed once MSC4153 (exclude insecure devices) is adopted.
    static let unverifiedDevicesViewModel = viewModel(.rooms, unverifiedDevicesCount: 2)
    static let unverifiedDevicesWithServiceMessageViewModel = viewModel(.rooms,
                                                                        unverifiedDevicesCount: 1,
                                                                        serviceMessage: .init(id: 1,
                                                                                              isCritical: false,
                                                                                              allowDismiss: true,
                                                                                              title: "Scheduled maintenance",
                                                                                              body: "Beam will be temporarily unavailable on Sunday between 02:00 and 04:00."))
    
    static var previews: some View {
        ElementNavigationStack {
            HomeScreen(context: loadingViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .skeletons
        })
        .previewDisplayName("Loading")
        
        ElementNavigationStack {
            HomeScreen(context: emptyViewModel.context)
        }
        .snapshotPreferences(expect: emptyViewModel.context.$viewState.map { state in
            state.roomListMode == .empty
        })
        .previewDisplayName("Empty")
        
        ElementNavigationStack {
            HomeScreen(context: loadedViewModel.context)
        }
        .snapshotPreferences(expect: loadedViewModel.context.$viewState.map { state in
            state.roomListMode == .rooms
        })
        .previewDisplayName("Loaded")
        
        // PG_CHANGED - TEMPORARY: unverified devices warning, to be removed once MSC4153 (exclude insecure devices) is adopted.
        ElementNavigationStack {
            HomeScreen(context: unverifiedDevicesViewModel.context)
        }
        .snapshotPreferences(expect: unverifiedDevicesViewModel.context.$viewState.map { state in
            state.roomListMode == .rooms && state.pgUnverifiedDevices != nil
        })
        .previewDisplayName("Unverified devices")
        
        // PG_CHANGED - TEMPORARY (MSC4153): both PG banners and no upstream banner below them, where their spacing is easy to get wrong.
        ElementNavigationStack {
            HomeScreen(context: unverifiedDevicesWithServiceMessageViewModel.context)
        }
        .snapshotPreferences(expect: unverifiedDevicesWithServiceMessageViewModel.context.$viewState.map { state in
            state.roomListMode == .rooms && state.pgUnverifiedDevices != nil && state.serviceMessage != nil
        })
        .previewDisplayName("Unverified devices with service message")
    }
    
    // PG_CHANGED - TEMPORARY: unverified devices warning, to be removed once MSC4153 (exclude insecure devices) is adopted.
    static func viewModel(_ mode: HomeScreenRoomListMode,
                          unverifiedDevicesCount: Int = 0,
                          serviceMessage: PgServiceMessageDisplay? = nil) -> HomeScreenViewModel {
        let userID = "@alice:example.com"
        
        let roomSummaryProviderState: RoomSummaryProviderMockConfigurationState = switch mode {
        case .skeletons:
            .loading
        case .empty:
            .loaded([])
        case .rooms:
            .loaded(.mockRooms)
        }
        
        let clientProxy = ClientProxyMock(.init(userID: userID,
                                                roomSummaryProvider: RoomSummaryProviderMock(.init(state: roomSummaryProviderState))))
        clientProxy.unverifiedOwnDevicesCountReturnValue = .success(unverifiedDevicesCount) // PG_CHANGED - TEMPORARY (MSC4153)
        
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        
        // PG_CHANGED - TEMPORARY (MSC4153): a service message to show next to the unverified devices warning.
        let pgServiceMessageService: PgServiceMessageServiceProtocol
        if let serviceMessage {
            let serviceMock = PgServiceMessageServiceMock()
            serviceMock.underlyingCurrentMessagePublisher = CurrentValueSubject<PgServiceMessageDisplay?, Never>(serviceMessage).asCurrentValuePublisher()
            pgServiceMessageService = serviceMock
        } else {
            pgServiceMessageService = PgServiceMessageService.mock(appSettings: AppSettings.volatile())
        }
        
        return HomeScreenViewModel(userSession: userSession,
                                   selectedRoomPublisher: CurrentValueSubject<String?, Never>(nil).asCurrentValuePublisher(),
                                   appSettings: .volatile(),
                                   analyticsService: AnalyticsServiceMock(.init()),
                                   notificationManager: NotificationManagerMock(),
                                   userIndicatorController: UserIndicatorControllerMock(),
                                   pgServiceMessageService: pgServiceMessageService) // PG_CHANGED
    }
}
