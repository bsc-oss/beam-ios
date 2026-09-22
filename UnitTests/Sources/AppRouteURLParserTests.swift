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

@testable import ElementX
import Foundation
import Testing

struct AppRouteURLParserTests {
    var appSettings: AppSettings
    var appRouteURLParser: AppRouteURLParser
    
    init() {
        AppSettings.resetAllSettings()
        appSettings = AppSettings()
        appRouteURLParser = AppRouteURLParser(appSettings: appSettings)
    }
    
    // PG_CHANGED - removed elementCallRoutes/customSchemeLinkCallRoutes tests: PG dropped the element.io
    // call parser and upstream removed the AppRoute.genericCallLink case they asserted against.
    @Test
    func customDomainUniversalLinkCallRoutes() throws {
        let url = try #require(URL(string: "https://somecustomdomain.element.io/test"))

        #expect(appRouteURLParser.route(from: url) == nil)
    }

    @Test
    func httpCustomSchemeLinkCallRoutes() throws {
        let customSchemeURL = try #require(URL(string: "io.element.call:/?url=http%3A%2F%2Fcall.element.io%2Ftest"))
        
        #expect(appRouteURLParser.route(from: customSchemeURL) == nil)
    }
    
    // PG_CHANGED - uses share.beam.belgium.be instead of matrix.to
    @Test
    func matrixUserURL() throws {
        let userID = "@test:matrix.org"
        let url = try #require(URL(string: "https://share.beam.belgium.be/#/\(userID)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .userProfile(userID: userID))
    }
    
    // PG_CHANGED - uses share.beam.belgium.be instead of matrix.to
    @Test
    func matrixRoomIdentifierURL() throws {
        let id = "!abcdefghijklmnopqrstuvwxyz1234567890:matrix.org"
        let url = try #require(URL(string: "https://share.beam.belgium.be/#/\(id)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .room(roomID: id, via: []))
    }
    
    // PG_CHANGED - removes element.io references
    @Test(.disabled())
    func webRoomIDURL() throws {
        let id = "!abcdefghijklmnopqrstuvwxyz1234567890:matrix.org"
        let url = try #require(URL(string: "https://app.element.io/#/room/\(id)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .room(roomID: id, via: []))
    }
    
    // PG_CHANGED - removes element.io references
    @Test(.disabled())
    func webUserIDURL() throws {
        let id = "@alice:matrix.org"
        let url = try #require(URL(string: "https://develop.element.io/#/user/\(id)"))
        
        let route = appRouteURLParser.route(from: url)
        
        #expect(route == .userProfile(userID: id))
    }
}
