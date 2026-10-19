//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Clocks
@testable import ElementX
import Testing

// PG_CHANGED - TEMPORARY: unverified devices warning, to be removed once MSC4153 (exclude insecure devices) is adopted.

// The TestClock advances by yielding to background tasks which can be starved on a busy CI runner.
@Suite(.timeLimit(.minutes(2)))
@MainActor
final class PgUnverifiedDevicesMonitorTests {
    private let clientProxy = ClientProxyMock(.init(deviceID: "ABCD1234"))
    private let appSettings = AppSettings.volatile()
    private let testClock = TestClock<Duration>()
    private lazy var monitor = PgUnverifiedDevicesMonitor(clientProxy: clientProxy, appSettings: appSettings, clock: testClock)
    
    @Test
    func warnsAboutUnverifiedDevices() async throws {
        try await appear(withUnverifiedDevices: 2)
        
        #expect(clientProxy.accountURLActionReceivedAction == .devicesList)
        #expect(monitor.unverifiedDevicesPublisher.value?.manageDevicesURL?.absoluteString
            == "https://matrix.org/account?pg_current_device_id=ABCD1234")
    }
    
    @Test
    func noWarningWithoutUnverifiedDevices() async {
        await waitForConfirmation { confirmation in
            clientProxy.unverifiedOwnDevicesCountClosure = {
                confirmation()
                return .success(0)
            }
            monitor.setVisible(true)
        }
        
        #expect(monitor.unverifiedDevicesPublisher.value == nil)
        #expect(!clientProxy.accountURLActionCalled)
    }
    
    @Test
    func nothingToWatchWhenInsecureDevicesAreExcluded() {
        appSettings.enableOnlySignedDeviceIsolationMode = true
        
        monitor.setVisible(true)
        
        #expect(!clientProxy.unverifiedOwnDevicesCountCalled)
    }
    
    @Test
    func pollsOnlyWhileThereAreUnverifiedDevices() async throws {
        try await appear(withUnverifiedDevices: 2)
        
        clientProxy.unverifiedOwnDevicesCountReturnValue = .success(0)
        let deferred = deferFulfillment(monitor.unverifiedDevicesPublisher) { $0 == nil }
        await testClock.advance(by: .seconds(30))
        try await deferred.fulfill()
        
        await testClock.advance(by: .seconds(60))
        #expect(clientProxy.unverifiedOwnDevicesCountCallsCount == 2)
    }
    
    @Test
    func retriesAFailedRead() async throws {
        await waitForConfirmation { confirmation in
            clientProxy.unverifiedOwnDevicesCountClosure = {
                confirmation()
                return .failure(.sdkError(ClientProxyMockError.generic))
            }
            monitor.setVisible(true)
        }
        
        clientProxy.unverifiedOwnDevicesCountClosure = nil
        clientProxy.unverifiedOwnDevicesCountReturnValue = .success(1)
        let deferred = deferFulfillment(monitor.unverifiedDevicesPublisher) { $0?.count == 1 }
        await testClock.advance(by: .seconds(30))
        try await deferred.fulfill()
    }
    
    @Test
    func stopsWhenTheRoomListGoesAway() async throws {
        try await appear(withUnverifiedDevices: 2)
        
        monitor.setVisible(false)
        await testClock.advance(by: .seconds(60))
        
        #expect(clientProxy.unverifiedOwnDevicesCountCallsCount == 1)
    }
    
    @Test
    func rechecksAfterTheDeviceManagementPageIsClosed() async throws {
        try await appear(withUnverifiedDevices: 2)
        
        let (page, continuation) = AsyncStream<Result<Void, OAuthError>>.makeStream()
        monitor.recheck(afterClosing: page)
        
        // Polling pauses while the page covers the room list.
        await testClock.advance(by: .seconds(60))
        #expect(clientProxy.unverifiedOwnDevicesCountCallsCount == 1)
        
        // Closing it reads right away, but the sync reporting the signed out devices hasn't landed yet.
        await waitForConfirmation { confirmation in
            clientProxy.unverifiedOwnDevicesCountClosure = {
                confirmation()
                return .success(2)
            }
            continuation.yield(.failure(.userCancellation))
            continuation.finish()
        }
        
        clientProxy.unverifiedOwnDevicesCountClosure = nil
        clientProxy.unverifiedOwnDevicesCountReturnValue = .success(0)
        let deferred = deferFulfillment(monitor.unverifiedDevicesPublisher) { $0 == nil }
        await testClock.advance(by: .seconds(2))
        try await deferred.fulfill()
    }
    
    // MARK: - Helpers
    
    private func appear(withUnverifiedDevices count: Int) async throws {
        clientProxy.unverifiedOwnDevicesCountReturnValue = .success(count)
        
        let deferred = deferFulfillment(monitor.unverifiedDevicesPublisher) { $0?.count == count }
        monitor.setVisible(true)
        try await deferred.fulfill()
    }
}
