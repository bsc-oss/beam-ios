//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-04-30

import Compound
import SwiftUI

// PG_CHANGED
struct KnockRequestInfo: Equatable, PgUserDescribing {
    let displayName: String?
    // PG_CHANGED
    let email: String?
    let avatarURL: URL?
    let userID: String
    let reason: String?
    let eventID: String
}

struct KnockRequestsBannerView: View {
    let requests: [KnockRequestInfo]
    let onDismiss: () -> Void
    let onAccept: ((String) -> Void)?
    let onViewAll: () -> Void
    var mediaProvider: MediaProviderProtocol?
    
    var body: some View {
        mainContent
            .padding(16)
            .background(.compound.bgCanvasDefaultLevel1, in: RoundedRectangle(cornerRadius: 12))
            .compositingGroup()
            .shadow(color: Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.1), radius: 12, x: 0, y: 4)
            .padding(.bottom, 28)
            .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if requests.count == 1 {
            SingleKnockRequestBannerContent(request: requests[0],
                                            onDismiss: onDismiss,
                                            onAccept: onAccept,
                                            onViewAll: onViewAll,
                                            mediaProvider: mediaProvider)
        } else if requests.count > 1 {
            MultipleKnockRequestsBannerContent(requests: requests,
                                               onDismiss: onDismiss,
                                               onViewAll: onViewAll,
                                               mediaProvider: mediaProvider)
        } else {
            EmptyView()
        }
    }
}

private struct SingleKnockRequestBannerContent: View {
    let request: KnockRequestInfo
    let onDismiss: () -> Void
    let onAccept: ((String) -> Void)?
    let onViewAll: () -> Void
    var mediaProvider: MediaProviderProtocol?
    
    var body: some View {
        VStack(spacing: 14) {
            header
            if let reason = request.reason {
                Text(reason)
                    .lineLimit(2)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            actions
        }
    }
    
    private var header: some View {
        HStack(spacing: 10) {
            LoadableAvatarImage(url: request.avatarURL,
                                name: request.displayName,
                                // PG_CHANGED
                                email: request.email,
                                contentID: request.userID,
                                avatarSize: .user(on: .knockingUserBanner), mediaProvider: mediaProvider)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    // PG_CHANGED
                    Text(L10n.screenRoomSingleKnockRequestTitle(request.primaryInfo))
                        .lineLimit(2)
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.compound.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    KnockRequestsBannerDismissButton(onDismiss: onDismiss)
                }
                // PG_CHANGED
                if let secondaryInfo = request.secondaryInfo {
                    Text(secondaryInfo)
                        .lineLimit(2)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private var actions: some View {
        HStack(spacing: 12) {
            Button(action: onViewAll) {
                Text(L10n.screenRoomSingleKnockRequestViewButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compound(.secondary, size: .medium))
            
            if let onAccept {
                Button { onAccept(request.eventID) } label: {
                    Text(L10n.screenRoomSingleKnockRequestAcceptButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.compound(.primary, size: .medium))
            }
        }
        .padding(.top, request.reason == nil ? 0 : 2)
        .frame(maxWidth: .infinity)
    }
}

private struct MultipleKnockRequestsBannerContent: View {
    let requests: [KnockRequestInfo]
    let onDismiss: () -> Void
    let onViewAll: () -> Void
    var mediaProvider: MediaProviderProtocol?
    
    private var avatars: [StackedAvatarInfo] {
        requests
            .prefix(3)
            // PG_CHANGED
            .map { .init(url: $0.avatarURL, name: $0.displayName, email: $0.email, contentID: $0.userID) }
    }
    
    private var multipleKnockRequestsTitle: String {
        guard let first = requests.first else {
            return ""
        }
        
        // PG_CHANGED
        let string = first.primaryInfo
        return L10n.tr("Localizable", "screen_room_multiple_knock_requests_title", string, avatars.count - 1)
    }
    
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                StackedAvatarsView(overlap: 16, lineWidth: 2, avatars: avatars, avatarSize: .user(on: .knockingUsersBannerStack), mediaProvider: mediaProvider)
                HStack(alignment: .top, spacing: 0) {
                    Text(multipleKnockRequestsTitle)
                        .lineLimit(2)
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.compound.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    KnockRequestsBannerDismissButton(onDismiss: onDismiss)
                }
            }
            Button {
                onViewAll()
            } label: {
                Text(L10n.screenRoomMultipleKnockRequestsViewAllButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compound(.primary, size: .medium))
        }
    }
}

private struct KnockRequestsBannerDismissButton: View {
    let onDismiss: () -> Void
    
    var body: some View {
        Button {
            onDismiss()
        } label: {
            CompoundIcon(\.close, size: .medium, relativeTo: .compound.bodySMSemibold)
                .foregroundColor(.compound.iconTertiary)
        }
        .alignmentGuide(.top) { _ in
            3
        }
    }
}

struct KnockRequestsBannerView_Previews: PreviewProvider, TestablePreview {
    // PG_CHANGED
    static let singleRequest: [KnockRequestInfo] = [.init(displayName: "Alice", email: "alice@matrix.org", avatarURL: nil, userID: "@alice:matrix.org", reason: nil, eventID: "1")]
    
    static let singleRequestWithReason: [KnockRequestInfo] = [.init(displayName: "Alice",
                                                                    // PG_CHANGED
                                                                    email: "alice@matrix.org",
                                                                    avatarURL: nil,
                                                                    userID: "@alice:matrix.org",
                                                                    reason: "Hey, I’d like to join this room because of xyz topic and I’d like to participate in the room.",
                                                                    eventID: "1")]
    
    // PG_CHANGED
    static let singleRequestNoDisplayName: [KnockRequestInfo] = [.init(displayName: nil, email: nil, avatarURL: nil, userID: "@alice:matrix.org", reason: nil, eventID: "1")]
    
    // PG_CHANGED
    static let singleRequestWithEmail: [KnockRequestInfo] = [.init(displayName: nil, email: "alice@matrix.org", avatarURL: nil, userID: "@alice:matrix.org", reason: nil, eventID: "1")]
    
    // PG_CHANGED
    static let multipleRequests: [KnockRequestInfo] = [
        .init(displayName: "Alice", email: "alice@matrix.org", avatarURL: nil, userID: "@alice:matrix.org", reason: nil, eventID: "1"),
        .init(displayName: "Bob", email: "bob@matrix.org", avatarURL: nil, userID: "@bob:matrix.org", reason: nil, eventID: "2"),
        .init(displayName: "Charlie", email: "charlie@matrix.org", avatarURL: nil, userID: "@charlie:matrix.org", reason: nil, eventID: "3"),
        .init(displayName: "Dan", email: "dan@matrix.org", avatarURL: nil, userID: "@dan:matrix.org", reason: nil, eventID: "4"),
        .init(displayName: "Test", email: "dan@matrix.org", avatarURL: nil, userID: "@dan:matrix.org", reason: nil, eventID: "5")
    ]
    
    static var previews: some View {
        KnockRequestsBannerView(requests: singleRequest) { } onAccept: { _ in } onViewAll: { }
            .previewDisplayName("Single Request")
        // swiftlint:disable:next trailing_closure
        KnockRequestsBannerView(requests: singleRequest, onDismiss: { }, onAccept: nil, onViewAll: { })
            .previewDisplayName("Single Request, no accept action")
        KnockRequestsBannerView(requests: singleRequestWithReason) { } onAccept: { _ in } onViewAll: { }
            .previewDisplayName("Single Request with reason")
        KnockRequestsBannerView(requests: singleRequestNoDisplayName) { } onAccept: { _ in } onViewAll: { }
            .previewDisplayName("Single Request, No Display Name")
        
        // PG_CHANGED
        KnockRequestsBannerView(requests: singleRequestWithEmail) { } onAccept: { _ in } onViewAll: { }
            .previewDisplayName("Single Request, With Emai")
        
        KnockRequestsBannerView(requests: multipleRequests) { } onAccept: { _ in } onViewAll: { }
            .previewDisplayName("Multiple Requests")
    }
}
