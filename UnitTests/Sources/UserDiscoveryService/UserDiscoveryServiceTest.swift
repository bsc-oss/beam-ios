//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-09-25

@testable import ElementX
import MatrixRustSDK
import Testing

// PG_CHANGED - MatrixRustSDK also declares `UserProfile`, imported for the mapping test below
private typealias UserProfile = ElementX.UserProfile

@MainActor
struct UserDiscoveryServiceTest {
    private var service: UserDiscoveryService
    private var clientProxy: ClientProxyMock
    
    private var searchResults: [UserProfile] {
        [.mockAlice, .mockBob, .mockCharlie]
    }
    
    init() {
        clientProxy = .init(.init(userID: "@foo:matrix.org"))
        service = UserDiscoveryService(clientProxy: clientProxy)
    }
    
    @Test
    func queryShowingResults() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: [UserProfile.mockAlice], limited: true))
        
        let results = await (try? search(query: "AAA").get()) ?? []
        assertSearchResults(results, toBe: 1)
    }
    
    @Test
    func ownerIsFiltered() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: [UserProfile(userID: "@foo:matrix.org")], limited: true))
        
        let results = await (try? search(query: "AAA").get()) ?? []
        assertSearchResults(results, toBe: 0)
    }
    
    @Test
    func getProfileIsNotCalled() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: searchResults, limited: true))
        clientProxy.profileForReturnValue = .success(.init(userID: "@alice:matrix.org"))
        
        let results = await (try? search(query: "AAA").get()) ?? []
        assertSearchResults(results, toBe: 3)
        #expect(!clientProxy.profileForCalled)
    }
    
    @Test
    func getProfileIsNotCalledForAccountOwnerID() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: searchResults, limited: true))
        clientProxy.profileForReturnValue = .success(.init(userID: "@alice:matrix.org"))
        
        let results = await (try? search(query: "foo:matrix.org").get()) ?? []
        assertSearchResults(results, toBe: 3)
        #expect(!clientProxy.profileForCalled)
    }
    
    @Test
    func localResultShows() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: searchResults, limited: true))
        clientProxy.profileForReturnValue = .success(.init(userID: "@some:matrix.org"))
        
        let results = await (try? search(query: "@a:b.com").get()) ?? []
        
        assertSearchResults(results, toBe: 4)
        #expect(clientProxy.profileForCalled)
    }
    
    @Test
    func localResultShowsOnSearchError() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .failure(.sdkError(ClientProxyMockError.generic))
        clientProxy.profileForReturnValue = .success(.init(userID: "@some:matrix.org"))
        
        let results = await (try? search(query: "@a:b.com").get()) ?? []
        
        assertSearchResults(results, toBe: 1)
        #expect(clientProxy.profileForCalled)
    }
    
    @Test
    func searchErrorTriggers() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .failure(.sdkError(ClientProxyMockError.generic))
        clientProxy.profileForReturnValue = .success(.init(userID: "@some:matrix.org"))
        
        switch await search(query: "some query") {
        case .success:
            Issue.record("Search users must fail")
        case .failure(let error):
            #expect(error == UserDiscoveryErrorType.failedSearchingUsers)
        }
        
        #expect(!clientProxy.profileForCalled)
    }
    
    @Test
    func localResultWithDuplicates() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: searchResults, limited: true))
        clientProxy.profileForReturnValue = .success(.init(userID: "@bob:matrix.org"))
        
        let results = await (try? search(query: "@a:b.com").get()) ?? []
        
        assertSearchResults(results, toBe: 3)
        let firstUserID = results.first?.id
        #expect(firstUserID == "@bob:matrix.org")
        #expect(clientProxy.profileForCalled)
    }
    
    @Test
    func searchResultsShowWhenGetProfileFails() async {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: searchResults, limited: true))
        clientProxy.profileForReturnValue = .failure(.sdkError(ClientProxyMockError.generic))
        
        let results = await (try? search(query: "@a:b.com").get()) ?? []
        
        let firstUserID = results.first?.id
        #expect(firstUserID == "@a:b.com")
        #expect(clientProxy.profileForCalled)
    }
    
    // PG_CHANGED
    @Test
    func rateLimitedSearchKeepsProvenanceAndResolvesMatrixID() async throws {
        clientProxy.searchUsersSearchTermLimitReturnValue = .success(.init(results: [.mockAlice],
                                                                           knownFromRoomUserIDs: [UserProfile.mockAlice.id],
                                                                           serverError: .rateLimited))
        clientProxy.profileForReturnValue = .success(.init(userID: "@some:matrix.org"))
        
        let results = try await service.searchProfiles(with: "@a:b.com").get()
        
        // The profile endpoint is not the directory, so it can still answer.
        #expect(results.results.map(\.id) == ["@some:matrix.org", UserProfile.mockAlice.id])
        #expect(results.knownFromRoomUserIDs == [UserProfile.mockAlice.id])
        #expect(results.serverError == .rateLimited)
    }
    
    // PG_CHANGED
    @Test
    func mapsRustResults() {
        let rustResults = MatrixRustSDK.SearchUsersResults(results: [.init(profile: rustProfile("@alice:matrix.org"), knownFromRoom: true),
                                                                     .init(profile: rustProfile("@bob:matrix.org"), knownFromRoom: false)],
                                                           limited: false,
                                                           serverError: .init(kind: .limitExceeded(retryAfterMs: 10000), details: "Too many requests"))
        
        let results = SearchUsersResults(rustResults: rustResults)
        
        #expect(results.results.map(\.id) == ["@alice:matrix.org", "@bob:matrix.org"])
        #expect(results.knownFromRoomUserIDs == ["@alice:matrix.org"])
        #expect(results.serverError == .rateLimited)
        
        let unnamedFailure = MatrixRustSDK.SearchUsersResults(results: [], limited: false, serverError: .init(kind: nil, details: "offline"))
        #expect(SearchUsersResults(rustResults: unnamedFailure).serverError == .unavailable)
    }
    
    // MARK: - Private
    
    // PG_CHANGED
    private func rustProfile(_ userID: String) -> MatrixRustSDK.UserProfile {
        .init(userId: userID, displayName: nil, avatarUrl: nil, status: nil, call: nil, email: nil, department: nil,
              function: nil, phoneBookConsentType: nil, isProfileInitialized: nil, featureFlags: nil)
    }
    
    private func assertSearchResults(_ results: [UserProfile], toBe count: Int) {
        #expect(count >= 0)
        #expect(results.count == count)
        #expect(results.isEmpty == (count == 0))
    }
    
    private func search(query: String) async -> Result<[UserProfile], UserDiscoveryErrorType> {
        await service.searchProfiles(with: query).map(\.results) // PG_CHANGED
    }
}
