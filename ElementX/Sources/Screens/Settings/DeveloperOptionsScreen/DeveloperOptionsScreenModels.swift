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

import Foundation

enum DeveloperOptionsScreenViewModelAction {
    case clearCache
}

struct DeveloperOptionsScreenViewState: BindableState {
    let elementCallBaseURL: URL
    let appHooks: AppHooks
    var storeSizes: [StoreSize]?
    let shouldShowClearCache: Bool
    let isPresentedModally: Bool
    
    var bindings: DeveloperOptionsScreenViewStateBindings
    
    struct StoreSize: Identifiable {
        let name: String
        let size: String
        
        var id: String {
            name + size
        }
    }
}

// periphery: ignore - subscripts are seen as false positive
@dynamicMemberLookup
struct DeveloperOptionsScreenViewStateBindings {
    private let developerOptions: DeveloperOptionsProtocol

    init(developerOptions: DeveloperOptionsProtocol) {
        self.developerOptions = developerOptions
    }

    subscript<Setting>(dynamicMember keyPath: ReferenceWritableKeyPath<DeveloperOptionsProtocol, Setting>) -> Setting {
        get { developerOptions[keyPath: keyPath] }
        set { developerOptions[keyPath: keyPath] = newValue }
    }
}

enum DeveloperOptionsScreenViewAction {
    case clearCache
    case markAllRoomsAsRead
}

protocol DeveloperOptionsProtocol: AnyObject {
    var logLevel: LogLevel { get set }
    var traceLogPacks: Set<TraceLogPack> { get set }
    
    var enableOnlySignedDeviceIsolationMode: Bool { get set }
    var hideQuietNotificationAlerts: Bool { get set }
    var focusEventOnNotificationTap: Bool { get set }
    var automaticBackPaginationEnabled: Bool { get set }
    
    var roomListActivityVisibility: RoomListActivityVisibility { get set }
    var elementCallBaseURLOverride: URL? { get set }
    
    var fuzzyRoomListSearchEnabled: Bool { get set }
    var lowPriorityFilterEnabled: Bool { get set }
    var knockingEnabled: Bool { get set }
    
    var linkPreviewsEnabled: Bool { get set }
    
    // PG_CHANGED - labs is not accesible anymore, threads option added to developer options
    var threadsEnabled: Bool { get set }
    
    var linkNewDeviceEnabled: Bool { get set }
    var roomThreadListEnabled: Bool { get set }
    
    // PG_CHANGED - puts space/community feature behind a feature flag (disabled by default)
    var spacesEnabled: Bool { get set }
    
    // PG_CHANGED - allows viewSource, copyPermalink and report TimelineItemMenuAction only on dev builds
    var viewSourceEnabled: Bool { get set }
    var copyPermalinkEnabled: Bool { get set }
    var reportEnabled: Bool { get set }
    // PG_CHANGED - displays argus entrypoint based on argusEnabled developer option
    var argusEnabled: Bool { get set }

    // PG_CHANGED - PG feature flags surfaced in Developer Options (each disabled by default)
    var shareProfileEnabled: Bool { get set }
    var inviteFriendsEnabled: Bool { get set }
    var joinRoomByAddressEnabled: Bool { get set }
    var shareRoomEnabled: Bool { get set }
    var publicRoomCreationEnabled: Bool { get set }
    // PG_CHANGED - upstream removed the RoomDirectorySearch flag; PG keeps it (off by default, toggle via Developer Options only)
    var roomDirectorySearchEnabled: Bool { get set }

    // PG_CHANGED - upstream removed liveLocationSharingEnabled; PG keeps it (off by default, toggle via Developer Options only)
    var liveLocationSharingEnabled: Bool { get set }
}

extension AppSettings: DeveloperOptionsProtocol { }
