//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Combine
import UIKit

// PG_CHANGED - TEMPORARY: unverified devices warning, to be removed once MSC4153 (exclude insecure devices) is adopted.

struct PgUnverifiedDevices: Equatable {
    let count: Int
    /// The account provider page where the devices can be reviewed and signed out, or nil when the homeserver doesn't
    /// expose one. The warning is then shown without its action.
    let manageDevicesURL: URL?
}

/// Watches the devices of this account that were never verified, while the room list is in the foreground, so the
/// warning goes away as soon as they are verified or signed out.
///
/// There is nothing to watch while insecure devices are excluded from key sharing (MSC4153): room keys are then
/// withheld from unverified devices instead of making sends fail.
final class PgUnverifiedDevicesMonitor {
    private static let refreshInterval: Duration = .seconds(30)
    // How long to let sync catch up before re-reading the device list on return from the device management page,
    // and how many times to try. Reads are local, so a few of them cost nothing.
    private static let recheckDelay: Duration = .seconds(2)
    private static let recheckAttempts = 3
    
    private let clientProxy: ClientProxyProtocol
    private let appSettings: AppSettings
    private let clock: any Clock<Duration>
    
    private let unverifiedDevicesSubject = CurrentValueSubject<PgUnverifiedDevices?, Never>(nil)
    /// Nil while the account has no unverified device.
    var unverifiedDevicesPublisher: CurrentValuePublisher<PgUnverifiedDevices?, Never> {
        unverifiedDevicesSubject.asCurrentValuePublisher()
    }
    
    private var isVisible = false
    private var isManagingDevices = false
    private var manageDevicesURL: URL?
    @CancellableTask private var refreshTask: Task<Void, Never>?
    @CancellableTask private var recheckTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    init(clientProxy: ClientProxyProtocol, appSettings: AppSettings, clock: any Clock<Duration> = ContinuousClock()) {
        self.clientProxy = clientProxy
        self.appSettings = appSettings
        self.clock = clock
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.startRefreshing(reason: "app entered the foreground") }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.refreshTask = nil }
            .store(in: &cancellables)
    }
    
    /// The count is refreshed while the room list is on screen, and re-checked whenever it comes back.
    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        if isVisible {
            startRefreshing(reason: "room list appeared")
        } else {
            refreshTask = nil
        }
    }
    
    /// Re-checks the count once the device management page, which finishes `page` when closed, is dismissed.
    func recheck(afterClosing page: AsyncStream<Result<Void, OAuthError>>) {
        MXLog.info("Device management page opened")
        
        // The page covers the room list, so it's treated like the room list going away.
        isManagingDevices = true
        refreshTask = nil
        
        recheckTask = Task { [weak self, clock] in
            for await _ in page { }
            
            MXLog.info("Device management page closed")
            self?.isManagingDevices = false
            self?.startRefreshing(reason: "device management page closed")
            
            // A device signed out on that page stays in the local device list until the next sync reports the change,
            // which lands shortly after. So wait for it rather than querying the server, and re-read a few times in
            // case the sync is slow. The polling is the backstop.
            for attempt in 1...Self.recheckAttempts {
                try? await clock.sleep(for: Self.recheckDelay)
                guard !Task.isCancelled else { return }
                MXLog.verbose("Re-checking unverified devices, attempt \(attempt)/\(Self.recheckAttempts)")
                await self?.refresh()
            }
        }
    }
    
    // MARK: - Private
    
    private func startRefreshing(reason: String) {
        refreshTask = nil
        
        guard !appSettings.enableOnlySignedDeviceIsolationMode, isVisible, !isManagingDevices else {
            MXLog.verbose("Not watching unverified devices (\(reason))")
            return
        }
        
        MXLog.verbose("Watching unverified devices (\(reason))")
        refreshTask = Task { [weak self, clock] in
            // Polls only while there is something to watch: unverified devices are rare, and the count is re-checked
            // whenever the room list comes back.
            while !Task.isCancelled, await self?.refresh() == true {
                try? await clock.sleep(for: Self.refreshInterval)
            }
            MXLog.verbose(Task.isCancelled ? "Stopped watching unverified devices" : "No unverified devices left to watch")
        }
    }
    
    /// Reads the count, and returns whether it's still worth watching.
    @discardableResult
    private func refresh() async -> Bool {
        // A read that failed is retried rather than taken for "none". The failure itself is logged by the client proxy.
        guard case let .success(count) = await clientProxy.unverifiedOwnDevicesCount() else {
            MXLog.verbose("Couldn't read the unverified devices count, retrying on the next check")
            return true
        }
        
        MXLog.verbose("Unverified devices count: \(count)")
        
        guard count > 0 else {
            publish(nil)
            return false
        }
        
        // Resolved lazily and kept once we have it: most sessions never show the warning, and retrying while it's
        // missing means a hiccup on the first try doesn't leave the warning without its action.
        if manageDevicesURL == nil {
            manageDevicesURL = await clientProxy.pgAccountURL(action: .devicesList)
            if manageDevicesURL == nil {
                MXLog.verbose("No device management page available, the warning is shown without its action")
            }
        }
        publish(PgUnverifiedDevices(count: count, manageDevicesURL: manageDevicesURL))
        return true
    }
    
    private func publish(_ unverifiedDevices: PgUnverifiedDevices?) {
        let previous = unverifiedDevicesSubject.value
        guard previous != unverifiedDevices else { return }
        
        if previous?.count != unverifiedDevices?.count {
            MXLog.info("Unverified devices count changed from \(previous?.count ?? 0) to \(unverifiedDevices?.count ?? 0)")
        }
        unverifiedDevicesSubject.send(unverifiedDevices)
    }
}
