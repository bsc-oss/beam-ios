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
import Foundation
import MatrixRustSDK
import Testing

// PG_CHANGED: use of share.beam.belgium.be instead of matrix.to
/// Just for API sanity checking, they're already properly tested in the SDK/Ruma
struct PermalinkTests {
    @Test
    func userIdentifierPermalink() throws {
        let invalidUserId = "This1sN0tV4lid!@#$%^&*()"
        #expect(throws: (any Error).self) { try matrixToUserPermalink(userId: invalidUserId) }
        
        let validUserId = "@abcdefghijklmnopqrstuvwxyz1234567890._-=/:matrix.org"
        #expect(try matrixToUserPermalink(userId: validUserId) == "https://share.beam.belgium.be/#/@abcdefghijklmnopqrstuvwxyz1234567890._-=%2F:matrix.org")
    }
    
    @Test
    func permalinkDetection() {
        var url: URL = "https://www.matrix.org"
        #expect(parseMatrixEntityFrom(uri: url.absoluteString) == nil)
        
        url = "https://share.beam.belgium.be/#/@bob:matrix.org?via=matrix.org"
        #expect(parseMatrixEntityFrom(uri: url.absoluteString) ==
            MatrixEntity(id: .user(id: "@bob:matrix.org"),
                         via: ["matrix.org"]))
        
        url = "https://share.beam.belgium.be/#/!roomidentifier:matrix.org?via=matrix.org"
        #expect(parseMatrixEntityFrom(uri: url.absoluteString) ==
            MatrixEntity(id: .room(id: "!roomidentifier:matrix.org"),
                         via: ["matrix.org"]))
        
        url = "https://share.beam.belgium.be/#/%23roomalias:matrix.org?via=matrix.org"
        #expect(parseMatrixEntityFrom(uri: url.absoluteString) ==
            MatrixEntity(id: .roomAlias(alias: "#roomalias:matrix.org"),
                         via: ["matrix.org"]))
        
        url = "https://share.beam.belgium.be/#/!roomidentifier:matrix.org/$eventidentifier?via=matrix.org"
        #expect(parseMatrixEntityFrom(uri: url.absoluteString) ==
            MatrixEntity(id: .eventOnRoomId(roomId: "!roomidentifier:matrix.org", eventId: "$eventidentifier"),
                         via: ["matrix.org"]))
        
        url = "https://share.beam.belgium.be/#/#roomalias:matrix.org/$eventidentifier?via=matrix.org"
        #expect(parseMatrixEntityFrom(uri: url.absoluteString) ==
            MatrixEntity(id: .eventOnRoomAlias(alias: "#roomalias:matrix.org", eventId: "$eventidentifier"),
                         via: ["matrix.org"]))
    }
}
