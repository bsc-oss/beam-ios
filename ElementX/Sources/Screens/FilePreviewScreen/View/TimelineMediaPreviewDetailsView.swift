//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Compound
import SwiftUI

struct TimelineMediaPreviewDetailsView: View {
    let item: TimelineMediaPreviewItem.Media
    @ObservedObject var context: TimelineMediaPreviewViewModel.Context
    var preferredColorScheme: ColorScheme? = .dark
    // PG_CHANGED
    @State private var warningAction: AttachmentWarningAction?
    // PG_CHANGED
    @State private var shareSheetPayload: ShareSheetPayload?
    // PG_CHANGED
    @State private var blockedFileInfo: BlockedFileInfo?

    @Binding var sheetHeight: CGFloat
    
    private let topPadding: CGFloat = 19
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                details
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .readHeight($sheetHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(.top, topPadding) // For the drag indicator
        .presentationDetents([.height(sheetHeight + topPadding)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.compound.bgCanvasDefault)
        .preferredColorScheme(preferredColorScheme)
        .sheet(item: $context.redactConfirmationItem) { item in
            TimelineMediaPreviewRedactConfirmationView(item: item,
                                                       context: context,
                                                       preferredColorScheme: preferredColorScheme)
        }
        // PG_CHANGED
        .sheet(item: $warningAction) { action in
            AttachmentWarningSheetView(preferredColorScheme: preferredColorScheme) {
                handleWarningAction(action)
            }
        }
        // PG_CHANGED
        .sheet(item: $shareSheetPayload) { payload in
            AppActivityView(activityItems: payload.items)
        }
        // PG_CHANGED
        .sheet(item: $blockedFileInfo) { info in
            BlockedFileTypeSheetView(preferredColorScheme: preferredColorScheme,
                                     filename: info.filename,
                                     fileExtension: info.fileExtension)
        }
    }
    
    private var details: some View {
        VStack(alignment: .leading, spacing: 20) {
            DetailsRow(title: L10n.screenMediaDetailsUploadedBy) {
                HStack(spacing: 12) {
                    LoadableAvatarImage(url: item.sender.avatarURL,
                                        name: item.sender.displayName,
                                        // PG_CHANGED
                                        email: item.sender.email,
                                        contentID: item.sender.id,
                                        avatarSize: .user(on: .mediaPreviewDetails),
                                        mediaProvider: context.mediaProvider)
                        .accessibilityHidden(true)

                    // PG_CHANGED - primaryInfo/secondaryInfo (email-aware) with upstream's updated spacing/fonts
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.sender.primaryInfo)
                            .font(.compound.bodyLGSemibold)
                            .foregroundStyle(.compound.decorativeColor(for: item.sender.id).text)

                        if let secondaryInfo = item.sender.secondaryInfo {
                            Text(secondaryInfo)
                                .font(.compound.bodyMD)
                                .foregroundStyle(.compound.textSecondary)
                        }
                    }
                }
            }
            
            DetailsRow(title: L10n.screenMediaDetailsUploadedOn) {
                Text(item.timestamp.formatted(date: .long, time: .shortened))
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
            }
            
            DetailsRow(title: L10n.screenMediaDetailsFilename) {
                Text(item.filename ?? "")
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
            }
            
            if let contentType = item.contentType {
                DetailsRow(title: L10n.screenMediaDetailsFileFormat) {
                    Group {
                        if let fileSize = item.fileSize {
                            Text(contentType) + Text(" • ") + Text(UInt(fileSize).formatted(.byteCount(style: .file)))
                        } else {
                            Text(contentType)
                        }
                    }
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var actions: some View {
        if let actions = context.viewState.currentItemActions {
            VStack(spacing: 0) {
                if !actions.actions.isEmpty {
                    Divider()
                        .background(Color.compound.bgSubtlePrimary)
                }
                
                ForEach(actions.actions, id: \.self) { action in
                    ActionButton(item: item,
                                 action: action,
                                 context: context,
                                 // PG_CHANGED
                                 onShare: showShareWarning,
                                 onSave: showSaveWarning,
                                 onBlocked: showBlockedAlert)
                }
                
                if !actions.secondaryActions.isEmpty {
                    Divider()
                        .background(Color.compound.bgSubtlePrimary)
                }
                
                ForEach(actions.secondaryActions, id: \.self) { action in
                    ActionButton(item: item,
                                 action: action,
                                 context: context,
                                 // PG_CHANGED
                                 onShare: showShareWarning,
                                 onSave: showSaveWarning,
                                 onBlocked: showBlockedAlert)
                }
            }
        }
    }
    
    private struct DetailsRow<Content: View>: View {
        let title: String
        let content: () -> Content
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(Compound.supportsGlass ? .compound.bodyMDSemibold : .compound.bodyXS)
                    .foregroundStyle(.compound.textSecondary)
                    .textCase(Compound.supportsGlass ? nil : .uppercase)
                
                content()
            }
        }
    }
    
    // PG_CHANGED
    private struct ActionButton: View {
        let item: TimelineMediaPreviewItem.Media
        let action: TimelineItemMenuAction
        let context: TimelineMediaPreviewViewModel.Context
        let onShare: (URL, String?) -> Void
        let onSave: () -> Void
        let onBlocked: (String, String) -> Void
        
        var body: some View {
            if action == .share {
                if let itemURL = item.fileHandle?.url {
                    Button {
                        if item.isBlockedFileType {
                            onBlocked(item.filename ?? "", item.fileExtension ?? "")
                        } else {
                            onShare(itemURL, item.caption)
                        }
                    } label: {
                        action.label
                    }
                    .buttonStyle(.menuSheet)
                }
            } else if action == .save {
                if item.fileHandle?.url != nil {
                    Button(role: action.isDestructive ? .destructive : nil) {
                        if item.isBlockedFileType {
                            onBlocked(item.filename ?? "", item.fileExtension ?? "")
                        } else {
                            onSave()
                        }
                    } label: {
                        action.label
                    }
                    .buttonStyle(.menuSheet)
                }
            } else {
                button
            }
        }
        
        var button: some View {
            Button(role: action.isDestructive ? .destructive : nil) {
                context.send(viewAction: .menuAction(action, item: item))
            } label: {
                action.label
            }
            .buttonStyle(.menuSheet)
        }
    }
    
    // PG_CHANGED
    private func showShareWarning(url: URL, caption: String?) {
        warningAction = .init(kind: .share(url: url, caption: caption))
    }
    
    // PG_CHANGED
    private func showSaveWarning() {
        warningAction = .init(kind: .save)
    }
    
    // PG_CHANGED
    private func showBlockedAlert(filename: String, fileExtension: String) {
        blockedFileInfo = .init(filename: filename, fileExtension: fileExtension)
    }
    
    // PG_CHANGED
    private func handleWarningAction(_ action: AttachmentWarningAction) {
        warningAction = nil
        switch action.kind {
        case .share(let url, let caption):
            var items: [Any] = []
            if let caption {
                items.append(caption)
            }
            items.append(url)
            shareSheetPayload = .init(items: items)
        case .save:
            context.send(viewAction: .menuAction(.save, item: item))
        }
    }
    
    // PG_CHANGED
    private struct AttachmentWarningAction: Identifiable {
        enum Kind {
            case share(url: URL, caption: String?)
            case save
        }
        
        let id = UUID()
        let kind: Kind
    }
    
    // PG_CHANGED
    private struct ShareSheetPayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }
    
    // PG_CHANGED
    private struct BlockedFileInfo: Identifiable {
        let id = UUID()
        let filename: String
        let fileExtension: String
    }
}

// MARK: - Previews

import UniformTypeIdentifiers

struct TimelineMediaPreviewDetailsView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel(contentType: .jpeg, isOutgoing: true)
    static let loadingViewModel = makeViewModel(contentType: .jpeg, isOutgoing: true, isDownloaded: false)
    static let unknownTypeViewModel = makeViewModel()
    static let presentedOnRoomViewModel = makeViewModel(isPresentedOnRoomScreen: true)
    
    @State static var sheetHeight: CGFloat = .zero
    
    static var previews: some View {
        if case let .media(mediaItem) = viewModel.state.currentItem {
            TimelineMediaPreviewDetailsView(item: mediaItem, context: viewModel.context, sheetHeight: $sheetHeight)
                .previewDisplayName("Image")
                .snapshotPreferences(expect: mediaItem.observe(\.fileHandle).map { $0 != nil })
        }
        
        if case let .media(mediaItem) = loadingViewModel.state.currentItem {
            TimelineMediaPreviewDetailsView(item: mediaItem, context: loadingViewModel.context, sheetHeight: $sheetHeight)
                .previewDisplayName("Loading")
        }
        
        if case let .media(mediaItem) = unknownTypeViewModel.state.currentItem {
            TimelineMediaPreviewDetailsView(item: mediaItem, context: unknownTypeViewModel.context, sheetHeight: $sheetHeight)
                .previewDisplayName("Unknown type")
                .snapshotPreferences(expect: mediaItem.observe(\.fileHandle).map { $0 != nil })
        }
        
        if case let .media(mediaItem) = presentedOnRoomViewModel.state.currentItem {
            TimelineMediaPreviewDetailsView(item: mediaItem, context: presentedOnRoomViewModel.context, sheetHeight: $sheetHeight)
                .previewDisplayName("Incoming on Room")
                .snapshotPreferences(expect: mediaItem.observe(\.fileHandle).map { $0 != nil })
        }
    }
    
    static func makeViewModel(contentType: UTType? = nil,
                              isOutgoing: Bool = false,
                              isDownloaded: Bool = true,
                              isPresentedOnRoomScreen: Bool = false) -> TimelineMediaPreviewViewModel {
        let item = ImageRoomTimelineItem(id: .randomEvent,
                                         timestamp: .mock,
                                         isOutgoing: isOutgoing,
                                         isEditable: true,
                                         canBeRepliedTo: true,
                                         sender: .init(id: "@alice:matrix.org",
                                                       displayName: "Alice",
                                                       email: "alice@matrix.org",
                                                       avatarURL: .mockMXCUserAvatar),
                                         content: .init(filename: "Amazing Image.jpeg",
                                                        imageInfo: .mockImage,
                                                        thumbnailInfo: .mockThumbnail,
                                                        contentType: contentType))
        
        let timelineKind = TimelineKind.media(isPresentedOnRoomScreen ? .roomScreenLive : .mediaFilesScreen)
        let timelineController = MockTimelineController(timelineKind: timelineKind)
        timelineController.timelineItems = [item]
        
        let viewModel = TimelineMediaPreviewViewModel(initialItem: item,
                                                      timelineViewModel: TimelineViewModel.mock(timelineKind: timelineKind,
                                                                                                timelineController: timelineController),
                                                      mediaProvider: MediaProviderMock(configuration: .init()),
                                                      photoLibraryManager: PhotoLibraryManagerMock(.init()),
                                                      userIndicatorController: UserIndicatorControllerMock(),
                                                      appMediator: AppMediatorMock())
        
        if isDownloaded {
            viewModel.context.send(viewAction: .updateCurrentItem(viewModel.state.currentItem))
        }
        
        return viewModel
    }
}
