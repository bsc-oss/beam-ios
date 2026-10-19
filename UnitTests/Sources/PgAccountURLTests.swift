//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

@MainActor
struct PgAccountURLTests {
    @Test
    func startsAQueryWhenTheURLHasNone() {
        #expect(url("https://account.example.org/devices").appendingPgCurrentDeviceID("ABCD1234").absoluteString
            == "https://account.example.org/devices?pg_current_device_id=ABCD1234")
    }
    
    @Test
    func appendsToAnExistingQuery() {
        #expect(url("https://account.example.org/?action=org.matrix.devices_list").appendingPgCurrentDeviceID("ABCD1234").absoluteString
            == "https://account.example.org/?action=org.matrix.devices_list&pg_current_device_id=ABCD1234")
    }
    
    @Test
    func keepsTheParameterOutOfTheFragment() {
        // Appended at the end it would land inside the fragment, which never reaches the server.
        #expect(url("https://account.example.org/account#/devices").appendingPgCurrentDeviceID("ABCD1234").absoluteString
            == "https://account.example.org/account?pg_current_device_id=ABCD1234#/devices")
        #expect(url("https://account.example.org/account#/devices?tab=all").appendingPgCurrentDeviceID("ABCD1234").absoluteString
            == "https://account.example.org/account?pg_current_device_id=ABCD1234#/devices?tab=all")
    }
    
    @Test
    func encodesTheDeviceID() {
        // Device IDs are opaque, so nothing stops one from carrying characters that would read as more query parameters.
        #expect(url("https://account.example.org/devices").appendingPgCurrentDeviceID("A B&c=d").absoluteString
            == "https://account.example.org/devices?pg_current_device_id=A%20B%26c%3Dd")
    }
    
    @Test
    func accountURLTellsTheDeviceID() async {
        let clientProxy = ClientProxyMock(.init(deviceID: "ABCD1234"))
        
        let accountURL = await clientProxy.pgAccountURL(action: .profile)
        
        #expect(accountURL?.absoluteString == "https://matrix.org/account?pg_current_device_id=ABCD1234")
        #expect(clientProxy.accountURLActionReceivedAction == .profile)
    }
    
    @Test
    func accountURLWithoutDeviceID() async {
        let clientProxy = ClientProxyMock(.init())
        
        #expect(await clientProxy.pgAccountURL(action: .profile)?.absoluteString == "https://matrix.org/account")
    }
    
    @Test
    func noAccountURL() async {
        let clientProxy = ClientProxyMock(.init(deviceID: "ABCD1234"))
        clientProxy.accountURLActionReturnValue = nil
        
        #expect(await clientProxy.pgAccountURL(action: .profile) == nil)
    }
    
    private func url(_ string: String) -> URL {
        URL(string: string)! // swiftlint:disable:this force_unwrapping
    }
}
