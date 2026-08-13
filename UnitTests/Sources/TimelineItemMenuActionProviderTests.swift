//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

@testable import ElementX
import Testing

// PG_CHANGED
@MainActor
struct TimelineItemMenuActionProviderTests {
    private var emojiProvider: EmojiProviderProtocol
    
    init() {
        emojiProvider = EmojiProvider(appSettings: AppSettings()) // PG_CHANGED - ServiceLocator removed upstream
    }
    
    // MARK: - Translate feature flag tests
    
    @Test
    func translateActionShownWhenEnabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isTranslateEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(actions.actions.contains(.translate),
                "Translate action should appear when isTranslateEnabled is true")
    }
    
    @Test
    func translateActionHiddenWhenDisabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isTranslateEnabled: false)
        
        let actions = try #require(provider.makeActions())
        
        #expect(!actions.actions.contains(.translate),
                "Translate action should not appear when isTranslateEnabled is false")
    }
    
    @Test
    func translateActionNotShownForNonCopyableItems() throws {
        let item = makeImageItem()
        let provider = makeProvider(item: item, isTranslateEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(!actions.actions.contains(.translate),
                "Translate action should not appear for non-copyable items even when enabled")
    }
    
    // MARK: - Copy Permalink feature flag tests
    
    @Test
    func copyPermalinkActionShownWhenEnabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isCopyPermalinkEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(actions.actions.contains(.copyPermalink),
                "CopyPermalink action should appear when isCopyPermalinkEnabled is true")
    }
    
    @Test
    func copyPermalinkActionHiddenWhenDisabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isCopyPermalinkEnabled: false)
        
        let actions = try #require(provider.makeActions())
        
        #expect(!actions.actions.contains(.copyPermalink),
                "CopyPermalink action should not appear when isCopyPermalinkEnabled is false")
    }
    
    // MARK: - View Source feature flag tests
    
    @Test
    func viewSourceActionShownWhenEnabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isViewSourceEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(actions.actions.contains(.viewSource),
                "ViewSource action should appear when isViewSourceEnabled is true")
    }
    
    @Test
    func viewSourceActionHiddenWhenDisabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isViewSourceEnabled: false)
        
        let actions = try #require(provider.makeActions())
        
        #expect(!actions.actions.contains(.viewSource),
                "ViewSource action should not appear when isViewSourceEnabled is false")
    }
    
    // MARK: - Report feature flag tests
    
    @Test
    func reportActionShownWhenEnabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isReportEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(actions.secondaryActions.contains(.report),
                "Report action should appear when isReportEnabled is true")
    }
    
    @Test
    func reportActionHiddenWhenDisabled() throws {
        let item = makeTextItem()
        let provider = makeProvider(item: item, isReportEnabled: false)
        
        let actions = try #require(provider.makeActions())
        
        #expect(!actions.secondaryActions.contains(.report),
                "Report action should not appear when isReportEnabled is false")
    }
    
    @Test
    func reportActionNotShownForOutgoingItems() throws {
        let item = makeOutgoingTextItem()
        let provider = makeProvider(item: item, isReportEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(!actions.secondaryActions.contains(.report),
                "Report action should not appear for outgoing items even when enabled")
    }
    
    // MARK: - Encrypted item tests
    
    @Test
    func encryptedItemCopyPermalinkShownWhenEnabled() throws {
        let item = makeEncryptedItem()
        let provider = makeProvider(item: item, isCopyPermalinkEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(actions.actions.contains(.copyPermalink),
                "CopyPermalink action should appear for encrypted items when isCopyPermalinkEnabled is true")
    }
    
    @Test
    func encryptedItemCopyPermalinkHiddenWhenDisabled() {
        let item = makeEncryptedItem()
        let provider = makeProvider(item: item, isCopyPermalinkEnabled: false)
        
        let actions = provider.makeActions()
        
        // When copyPermalink is disabled (and viewSource is also disabled by default),
        // encrypted items may have no menu at all (returns nil)
        if let actions {
            #expect(!actions.actions.contains(.copyPermalink),
                    "CopyPermalink action should not appear for encrypted items when isCopyPermalinkEnabled is false")
        }
        // If actions is nil, the test passes since copyPermalink is definitely not shown
    }
    
    @Test
    func encryptedItemViewSourceShownWhenEnabled() throws {
        let item = makeEncryptedItem()
        let provider = makeProvider(item: item, isViewSourceEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(actions.actions.contains(.viewSource),
                "ViewSource action should appear for encrypted items when isViewSourceEnabled is true")
    }
    
    @Test
    func encryptedItemShowsBothActionsWhenBothEnabled() throws {
        let item = makeEncryptedItem()
        let provider = makeProvider(item: item, isViewSourceEnabled: true, isCopyPermalinkEnabled: true)
        
        let actions = try #require(provider.makeActions())
        
        #expect(actions.actions.contains(.copyPermalink),
                "CopyPermalink action should appear for encrypted items when isCopyPermalinkEnabled is true")
        #expect(actions.actions.contains(.viewSource),
                "ViewSource action should appear for encrypted items when isViewSourceEnabled is true")
    }
    
    // MARK: - Helpers
    
    private func makeTextItem() -> TextRoomTimelineItem {
        TextRoomTimelineItem(id: .randomEvent,
                             timestamp: .mock,
                             isOutgoing: false,
                             isEditable: false,
                             canBeRepliedTo: true,
                             sender: .init(id: "@alice:matrix.org", displayName: "Alice"),
                             content: .init(body: "Hello, World!"))
    }
    
    private func makeOutgoingTextItem() -> TextRoomTimelineItem {
        TextRoomTimelineItem(id: .randomEvent,
                             timestamp: .mock,
                             isOutgoing: true,
                             isEditable: true,
                             canBeRepliedTo: true,
                             sender: .init(id: "@me:matrix.org", displayName: "Me"),
                             content: .init(body: "Hello, World!"))
    }
    
    private func makeImageItem() -> ImageRoomTimelineItem {
        ImageRoomTimelineItem(id: .randomEvent,
                              timestamp: .mock,
                              isOutgoing: false,
                              isEditable: false,
                              canBeRepliedTo: true,
                              sender: .init(id: "@alice:matrix.org", displayName: "Alice"),
                              content: .init(filename: "image.png",
                                             imageInfo: .mockImage,
                                             thumbnailInfo: nil))
    }
    
    private func makeEncryptedItem() -> EncryptedRoomTimelineItem {
        EncryptedRoomTimelineItem(id: .randomEvent,
                                  body: "Unable to decrypt",
                                  encryptionType: .unknown,
                                  timestamp: .mock,
                                  isOutgoing: false,
                                  isEditable: false,
                                  canBeRepliedTo: false,
                                  sender: .init(id: "@alice:matrix.org", displayName: "Alice"))
    }
    
    private func makeProvider(item: RoomTimelineItemProtocol,
                              isViewSourceEnabled: Bool = false,
                              isCopyPermalinkEnabled: Bool = false,
                              isReportEnabled: Bool = false,
                              isTranslateEnabled: Bool = false,
                              areThreadsEnabled: Bool = false) -> TimelineItemMenuActionProvider {
        TimelineItemMenuActionProvider(timelineItem: item,
                                       canCurrentUserSendMessage: true,
                                       canCurrentUserRedactSelf: true,
                                       canCurrentUserRedactOthers: false,
                                       canCurrentUserPin: false,
                                       pinnedEventIDs: [],
                                       isDM: false,
                                       isViewSourceEnabled: isViewSourceEnabled,
                                       isCopyPermalinkEnabled: isCopyPermalinkEnabled,
                                       isReportEnabled: isReportEnabled,
                                       isTranslateEnabled: isTranslateEnabled,
                                       areThreadsEnabled: areThreadsEnabled,
                                       timelineKind: .live,
                                       emojiProvider: emojiProvider)
    }
}
