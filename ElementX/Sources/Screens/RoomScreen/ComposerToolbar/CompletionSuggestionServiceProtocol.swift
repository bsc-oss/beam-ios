//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import WysiwygComposer

struct SuggestionTrigger: Equatable {
    enum SuggestionType: Equatable {
        case user
        case room
    }
    
    let type: SuggestionType
    let text: String
    let range: NSRange
}

struct SuggestionItem: Identifiable, Equatable {
    enum SuggestionType: Equatable {
        case user(User)
        case allUsers(RoomAvatar)
        case room(Room)
    }
    
    // PG_CHANGED
    struct User: Equatable, PgUserDescribing {
        let id: String
        // PG_CHANGED
        var userID: String { id }
        let displayName: String?
        let avatarURL: URL?
        // PG_CHANGED
        let email: String?
    }
    
    struct Room: Equatable {
        let id: String
        let canonicalAlias: String
        let name: String
        let avatar: RoomAvatar
    }
    
    let suggestionType: SuggestionType
    let range: NSRange
    let rawSuggestionText: String
    
    var id: String {
        switch suggestionType {
        case .user(let user):
            user.id
        case .allUsers:
            PillUtilities.atRoom
        case .room(let room):
            room.id
        }
    }
    
    var displayName: String {
        switch suggestionType {
        case .allUsers:
            return PillUtilities.everyone
        case .user(let user):
            // PG_CHANGED
            return user.primaryInfo
        case .room(let room):
            return room.name
        }
    }
    
    var subtitle: String? {
        switch suggestionType {
        case .allUsers:
            return PillUtilities.atRoom
        case .user(let user):
            // PG_CHANGED
            return user.secondaryInfo
        case .room(let room):
            return room.canonicalAlias
        }
    }
}

// sourcery: AutoMockable
protocol CompletionSuggestionServiceProtocol {
    var suggestionsPublisher: AnyPublisher<[SuggestionItem], Never> { get }
    
    func processTextMessage(_ textMessage: String, selectedRange: NSRange)
    
    func setSuggestionTrigger(_ suggestionTrigger: SuggestionTrigger?)
}

extension WysiwygComposer.SuggestionPattern {
    var toElementPattern: SuggestionTrigger? {
        switch key {
        case .at:
            return SuggestionTrigger(type: .user, text: text, range: .init(location: Int(start), length: Int(end)))
        case .hash:
            return SuggestionTrigger(type: .room, text: text, range: .init(location: Int(start), length: Int(end)))
        default:
            return nil
        }
    }
}

extension CompletionSuggestionServiceMock {
    struct CompletionSuggestionServiceMockConfiguration {
        var suggestions: [SuggestionItem] = []
    }
    
    convenience init(configuration: CompletionSuggestionServiceMockConfiguration) {
        self.init()
        underlyingSuggestionsPublisher = Just(configuration.suggestions).eraseToAnyPublisher()
    }
}
