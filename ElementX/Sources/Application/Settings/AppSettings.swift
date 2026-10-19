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

#if IS_MAIN_APP
import EmbeddedElementCall
#endif

import Combine
import Foundation
import Macros
import SwiftUI

/// Common settings between app and NSE
nonisolated protocol CommonSettingsProtocol: AnyObject, Sendable {
    var lastNotificationBootTime: TimeInterval? { get set }
    var selectedNotificationTone: NotificationTone? { get set }
    
    var logLevel: LogLevel { get }
    var traceLogPacks: Set<TraceLogPack> { get }
    var bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> { get }
    var contentScannerURL: RemotePreference<URL?> { get }
    var forceDisableE2EE: RemotePreference<Bool> { get }
    var mapTilerConfiguration: RemotePreference<MapTilerConfiguration> { get }
    
    var enableOnlySignedDeviceIsolationMode: Bool { get }
    var threadsEnabled: Bool { get }
    var hideQuietNotificationAlerts: Bool { get }
}

// PG_CHANGED - redefines AppBuildType - start

nonisolated enum BuildConfiguration: CustomStringConvertible {
    case debug
    case release
    
    var description: String {
        switch self {
        case .debug: "Debug"
        case .release: "Release"
        }
    }
}

nonisolated enum AppScheme: String, CustomStringConvertible {
    case dev
    case tst
    case acc
    case prd
    
    var description: String {
        rawValue
    }
}

nonisolated struct AppBuildType {
    let configuration: BuildConfiguration
    let scheme: AppScheme
    
    var description: String {
        "\(configuration)-\(scheme)"
    }
    
    static var current: AppBuildType {
        let configuration: BuildConfiguration
        #if DEBUG
        configuration = .debug
        #else
        // PG_CHANGED - removed upstream's isNightlyBuild check (no nightly builds in PG)
        configuration = .release
        #endif
        
        let environment = InfoPlistReader.main.appEnvironment
        guard let scheme = AppScheme(rawValue: environment) else {
            MXLog.warning("Unknown app environment '\(environment)'; defaulting app scheme to production.")
            return AppBuildType(configuration: configuration, scheme: .prd)
        }
        
        return AppBuildType(configuration: configuration, scheme: scheme)
    }
}

// PG_CHANGED - redefines AppBuildType - end

/// Store Element specific app settings.
///
/// State is persisted in `UserDefaults`, which is thread-safe per Apple's documentation, hence `@unchecked`.
final nonisolated class AppSettings: @unchecked Sendable {
    static let suiteName: String = InfoPlistReader.main.appGroupIdentifier
    
    /// UserDefaults to be used on reads and writes.
    private let store: UserDefaultsProtocol
    
    static var appBuildType: AppBuildType {
        AppBuildType.current
    }
    
    func resetAllSettings() {
        MXLog.warning("Resetting the AppSettings.")
        store.reset()
    }
    
    func resetSessionSpecificSettings() {
        MXLog.warning("Resetting the user session specific AppSettings.")
        resetHasRunIdentityConfirmationOnboarding()
        // PG_CHANGED - also reset the profile creation onboarding preference
        resetHasRunProfileCreationOnboarding()
    }
    
    // MARK: - Hooks
    
    // swiftlint:disable:next function_parameter_count
    func override(accountProviders: [String],
                  allowOtherAccountProviders: Bool,
                  hideBrandChrome: Bool,
                  pushGatewayBaseURL: URL,
                  oAuthRedirectURL: URL,
                  oAuthClientURIPath: String?,
                  websiteURL: URL,
                  logoURL: URL,
                  copyrightURL: URL,
                  acceptableUseURL: URL,
                  privacyURL: URL,
                  encryptionURL: URL,
                  deviceVerificationURL: URL,
                  chatBackupDetailsURL: URL,
                  identityPinningViolationDetailsURL: URL,
                  historySharingDetailsURL: URL,
                  bugReportApplicationID: String,
                  analyticsTermsURL: URL?,
                  mapTilerConfiguration: MapTilerConfiguration) {
        self.accountProviders = accountProviders
        self.allowOtherAccountProviders = allowOtherAccountProviders
        self.hideBrandChrome = hideBrandChrome
        self.pushGatewayBaseURL = pushGatewayBaseURL
        self.oAuthRedirectURL = oAuthRedirectURL
        self.oAuthClientURIPath = oAuthClientURIPath
        self.websiteURL = websiteURL
        self.logoURL = logoURL
        self.copyrightURL = copyrightURL
        self.acceptableUseURL = acceptableUseURL
        self.privacyURL = privacyURL
        self.encryptionURL = encryptionURL
        self.deviceVerificationURL = deviceVerificationURL
        self.chatBackupDetailsURL = chatBackupDetailsURL
        self.identityPinningViolationDetailsURL = identityPinningViolationDetailsURL
        self.historySharingDetailsURL = historySharingDetailsURL
        self.bugReportApplicationID = bugReportApplicationID
        self.analyticsTermsURL = analyticsTermsURL
        self.mapTilerConfiguration = RemotePreference(mapTilerConfiguration)
    }
    
    // MARK: - Application
    
    /// The last known version of the app that was launched on this device, which is
    /// used to detect when migrations should be run. When `nil` the app may have been
    /// deleted between runs so should clear data in the shared container and keychain.
    @UserPreference
    var lastVersionLaunched: String?
    
    /// The Set of room identifiers of invites that the user already saw in the invites list.
    /// This Set is being used to implement badges for unread invites.
    @UserPreference(defaultValue: Set<String>())
    var seenInvites: Set<String>
    
    /// Defaults to `true` for new users, and we use a migration to set it to `false` for existing users.
    @UserPreference(defaultValue: true)
    var hasSeenNewSoundBanner: Bool
    
    /// The initial set of account providers shown to the user in the authentication flow.
    ///
    /// Account provider is the friendly term for the server name. It should not contain an `https` prefix and should
    /// match the last part of the user ID. For example `example.com` and not `https://matrix.example.com`.
    private(set) var accountProviders = ["matrix.org"]
    /// Whether or not the user is allowed to manually enter their own account provider or must select from one of `defaultAccountProviders`.
    private(set) var allowOtherAccountProviders = true
    /// Whether the components surrounding the app brand/logo should be hidden or not
    private(set) var hideBrandChrome = false
    
    /// The task identifier used for background app refresh. Also used in main target's the Info.plist
    // PG_CHANGED - derived from the per-environment bundle identifier
    let backgroundAppRefreshTaskIdentifier = InfoPlistReader.main.baseBundleIdentifier + ".background.refresh"
    
    // PG_CHANGED - replaces element.io web URLs references by beam.belgium.be
    private static func beamURL(_ path: String = "", injectLocale: Bool = true) -> URL {
        var fullURL = "https://" + InfoPlistReader.main.websiteDomain
        if injectLocale {
            let acceptedLocales = ["fr", "nl", "de", "en"]
            let deviceLocale = Locale.current.language.languageCode?.identifier ?? "en"
            let locale = acceptedLocales.contains(deviceLocale) ? deviceLocale : nil
            // If locale is not part of the accepted language, do not provide any locale so that the webapp can use its own default
            if let locale {
                fullURL += "/" + locale
            }
        }
        fullURL += path
        return URL(string: fullURL) ?? { fatalError("Invalid beam URL with path: \(path) - full URL: \(fullURL)") }()
    }
    
    /// A URL where users can go read more about the app.
    private(set) var websiteURL: URL = AppSettings.beamURL("", injectLocale: false)
    /// A URL that contains the app's logo that may be used when showing content in a web view.
    private(set) var logoURL: URL = AppSettings.beamURL("/mobile-icon.png", injectLocale: false)
    /// A URL that contains that app's copyright notice.
    private(set) var copyrightURL: URL = AppSettings.beamURL("/copyright")
    /// A URL that contains the app's Terms of use.
    private(set) var acceptableUseURL: URL = AppSettings.beamURL("/acceptable-use-policy-terms")
    /// A URL that contains the app's Privacy Policy.
    private(set) var privacyURL: URL = AppSettings.beamURL("/privacy")
    /// A URL where users can go read more about encryption in general.
    private(set) var encryptionURL: URL = AppSettings.beamURL("/help#encryption")
    /// A URL where users can go read more about device verification..
    private(set) var deviceVerificationURL: URL = AppSettings.beamURL("/help#encryption-device-verification")
    /// A URL where users can go read more about the chat backup.
    private(set) var chatBackupDetailsURL: URL = AppSettings.beamURL("/help#encryption5")
    /// A URL where users can go read more about identity pinning violations
    private(set) var identityPinningViolationDetailsURL: URL = AppSettings.beamURL("/help#encryption18")
    /// A URL describing how history sharing works
    // PG_CHANGED - replaces element.io web URLs references by beam.belgium.be; upstream's re-added
    // elementWebHosts/accountProvisioningHost/elementProAppStoreURL stay removed (no Element-domain link handling in Beam)
    private(set) var historySharingDetailsURL: URL = AppSettings.beamURL("/help#e2ee-history-sharing")
    
    @UserPreference(defaultValue: AppAppearance.system)
    var appAppearance: AppAppearance
    
    /// Tracks previous servers the user connected to for autocompletion purposes. Entries are made lowercase on write.
    @UserPreference(key: "previousServers", defaultValue: [])
    var previousServers: [String]
    
    var defaultServer: String {
        previousServers.first ?? accountProviders[0]
    }
    
    // MARK: - Security
    
    // PG_CHANGED: The PIN is mandatory only if the OS does not have a lock set up.
    /// The app must be locked with a PIN code as part of the authentication flow.
    let appLockIsMandatory = true
    /// The amount of time the app can remain in the background for without requesting the PIN/TouchID/FaceID.
    let appLockGracePeriod: TimeInterval = 2
    /// Any codes that the user isn't allowed to use for their PIN.
    let appLockPINCodeBlockList = ["0000", "1234"]
    /// The number of attempts the user has made to unlock the app with a PIN code (resets when unlocked).
    @UserPreference(defaultValue: 0)
    var appLockNumberOfPINAttempts: Int
    
    // MARK: - Authentication
    
    // PG_CHANGED - keep empty (no upstream thirdroom static registration)
    let oAuthStaticRegistrations: [URL: String] = [:]
    /// The redirect URL used for OAuth. This no longer uses universal links so we don't need the bundle ID to avoid conflicts between Element X, Nightly and PR builds.
    // PG_CHANGED - configurable redirect URL from Info.plist (OIDC_REDIRECT_URL per environment)
    private(set) var oAuthRedirectURL = URL(string: InfoPlistReader.main.oidcRedirectURL) ?? { fatalError("Invalid OAuth redirect URL") }()
    /// A path that is appended to `websiteURL` to form the OAuth `clientURI`. MAS uses `clientURI` as the identifier for a specific app, allowing us to
    /// distinguish the various clients we have for Android, iOS and Web from each other.
    /// Intentionally a distinct property so it can be easily overridden without having to manipulate the website URL.
    private(set) var oAuthClientURIPath: String? = "apps/ios"
    
    var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: InfoPlistReader.main.bundleDisplayName,
                           redirectURI: oAuthRedirectURL,
                           clientURI: oAuthClientURIPath.map { websiteURL.appending(path: $0) } ?? websiteURL,
                           logoURI: logoURL,
                           tosURI: acceptableUseURL,
                           policyURI: privacyURL,
                           staticRegistrations: oAuthStaticRegistrations.mapKeys { $0.absoluteString })
    }
    
    /// Whether or not the Create Account button is shown on the start screen.
    ///
    /// **Note:** Setting this to false doesn't prevent someone from creating an account when the selected homeserver's MAS allows registration.
    // PG_CHANGED
    let showCreateAccountButton = false
    
    // MARK: - Notifications
    
    // PG_CHANGED
    var pusherAppID = InfoPlistReader.main.baseBundleIdentifier + ".ios"
    
    // PG_CHANGED
    private(set) var pushGatewayBaseURL = URL(string: InfoPlistReader.main.pushGatewayBaseURL) ?? { fatalError("Invalid pushGatewayBaseURL") }()
    var pushGatewayNotifyEndpoint: URL {
        pushGatewayBaseURL.appending(path: "_matrix/push/v1/notify")
    }
    
    @UserPreference(defaultValue: true)
    var enableNotifications: Bool
    
    @UserPreference(defaultValue: true)
    var enableInAppNotifications: Bool
    
    @UserPreference(defaultValue: false)
    var hideQuietNotificationAlerts: Bool
    
    /// Tag describing which set of device specific rules a pusher executes.
    @UserPreference
    var pusherProfileTag: String?
    
    /// The device's last boot time as recorded by the NSE.
    @UserPreference
    var lastNotificationBootTime: TimeInterval?
    
    /// The sound played when delivering noisy notifications. If nil, use the ElementX default
    @UserPreference
    var selectedNotificationTone: NotificationTone?
    
    // MARK: - Logging
    
    @UserPreference(defaultValue: LogLevel.info)
    var logLevel: LogLevel
    
    @UserPreference(defaultValue: Set<TraceLogPack>())
    var traceLogPacks: Set<TraceLogPack>
    
    // MARK: - Bug report
    
    // PG_CHANGED
    let bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> = .init(.url(URL(string: InfoPlistReader.main.bugReportRageshakeURL) ?? { fatalError("Invalid bugReportRageshakeURL") }()))
    let bugReportSentryURL: URL? = Secrets.sentryDSN.flatMap { URL(string: $0) }
    let bugReportSentryRustURL: URL? = Secrets.sentryRustDSN.flatMap { URL(string: $0) }
    
    // PG_CHANGED - sets the rageshake application ID as the bundle identifier + .ios
    /// The name allocated by the bug report server
    private(set) var bugReportApplicationID = InfoPlistReader.main.baseBundleIdentifier + ".ios"
    
    // MARK: - Content scanner
    
    /// The base URL of the content scanner server used to scan media before it is downloaded.
    /// `nil` when content scanning is disabled.
    let contentScannerURL: RemotePreference<URL?> = .init(nil)
    
    // MARK: - Encryption
    
    /// Whether the server forbids the use of E2EE: new rooms are created unencrypted and
    /// enabling encryption on existing rooms is not offered.
    let forceDisableE2EE: RemotePreference<Bool> = .init(false)
    
    // MARK: - Analytics
    
    /// The configuration to use for analytics. Set to `nil` to disable analytics.
    let analyticsConfiguration: AnalyticsConfiguration? = AppSettings.makeAnalyticsConfiguration()
    // PG_CHANGED - replaces element.io web URLs references by beam.belgium.be
    /// The URL to open with more information about analytics terms. When this is `nil` the "Learn more" link will be hidden.
    private(set) var analyticsTermsURL: URL? = AppSettings.beamURL("/cookie-policy")
    /// Whether or not there the app is able ask for user consent to enable analytics or sentry reporting.
    var canPromptForAnalytics: Bool {
        analyticsConfiguration != nil || bugReportSentryURL != nil
    }
    
    private static func makeAnalyticsConfiguration() -> AnalyticsConfiguration? {
        guard let host = Secrets.postHogHost, let apiKey = Secrets.postHogAPIKey else { return nil }
        return AnalyticsConfiguration(host: host, apiKey: apiKey)
    }
    
    /// Whether the user has opted in to send analytics.
    @UserPreference(defaultValue: AnalyticsConsentState.unknown)
    var analyticsConsentState: AnalyticsConsentState
    
    /// Whether a user session has ever been set up on this device. Deliberately not cleared on
    /// logout: it stops the Classic app migration prompt from reappearing when an Element X
    /// user is signed out unexpectedly (invalidated token, corrupted storage, etc).
    @UserPreference(defaultValue: false)
    var hasSignedInBefore: Bool
    
    // PG_CHANGED - adds custom profile fields
    @UserPreference(defaultValue: false)
    var hasRunProfileCreationOnboarding: Bool
    
    @UserPreference(defaultValue: false)
    var hasRunNotificationPermissionsOnboarding: Bool
    
    @UserPreference(defaultValue: false)
    var hasRunIdentityConfirmationOnboarding: Bool
    
    @UserPreference(defaultValue: false)
    var hasRequestedLocationAlwaysLocationAuthorization: Bool
    
    @UserPreference(defaultValue: [FrequentlyUsedEmoji]())
    var frequentlyUsedSystemEmojis: [FrequentlyUsedEmoji]
    
    // MARK: - Live Location
    
    @UserPreference(key: "liveLocationSharingTimeoutDatesByRoomID", defaultValue: [String: LiveLocationSession]())
    var liveLocationSharingSessionsByRoomID: [String: LiveLocationSession]
    
    @UserPreference(defaultValue: 10)
    var liveLocationMinimumDistanceUpdate: Int
    
    @UserPreference(defaultValue: false)
    var liveLocationDisclaimerDisplayed: Bool
    
    // MARK: - Home Screen
    
    @UserPreference(defaultValue: RoomListActivityVisibility.current)
    var roomListActivityVisibility: RoomListActivityVisibility
    
    // MARK: - Room Screen
    
    // PG_CHANGED - allows viewSource TimelineItemMenuAction only on dev builds
    @UserPreference(defaultValue: false)
    var viewSourceEnabled: Bool
    
    // PG_CHANGED - allows copyPermalink TimelineItemMenuAction only on dev builds
    @UserPreference(defaultValue: false)
    var copyPermalinkEnabled: Bool
    
    // PG_CHANGED - allows report TimelineItemMenuAction only on dev builds
    @UserPreference(defaultValue: false)
    var reportEnabled: Bool
    
    // PG_CHANGED - displays argus entrypoint based on argusEnabled developer option
    @UserPreference(defaultValue: false)
    var argusEnabled: Bool
    
    // PG_CHANGED - puts translate TimelineItemMenuAction behind a feature flag (disabled by default)
    @UserPreference(defaultValue: false)
    var translateEnabled: Bool
    
    @UserPreference(defaultValue: true)
    var optimizeMediaUploads: Bool
    
    @UserPreference(defaultValue: AudioPlaybackSpeed.default)
    var voiceMessagePlaybackSpeed: AudioPlaybackSpeed
    
    /// Whether or not to show a warning on the media caption composer so the user knows
    /// that captions might not be visible to users who are using other Matrix clients.
    let shouldShowMediaCaptionWarning = false // PG_CHANGED
    
    // MARK: - Element Call
    
    #if IS_MAIN_APP
    // swiftlint:disable:next force_unwrapping
    let elementCallBaseURL: URL = EmbeddedElementCall.appURL!
    #endif
    
    // These are publicly availble on https://call.element.io so we don't neeed to treat them as secrets
    // PG_CHANGED
    let elementCallPosthogAPIHost = ""
    let elementCallPosthogAPIKey = ""
    let elementCallPosthogSentryDSN = ""
    
    @UserPreference
    var elementCallBaseURLOverride: URL?
    
    // MARK: - Users
    
    /// Whether to hide the display name and avatar of ignored users as these may contain objectionable content.
    let hideIgnoredUserProfiles = true
    
    // MARK: - Maps
    
    /// The locally-bundled MapTiler configuration.
    static let bundledMapTilerConfiguration = MapTilerConfiguration(baseURL: "https://api.maptiler.com/maps",
                                                                    apiKey: Secrets.mapLibreAPIKey,
                                                                    lightStyleID: "9bc819c8-e627-474a-a348-ec144fe3d810",
                                                                    darkStyleID: "dea61faf-292b-4774-9660-58fcef89a7f3")
    
    /// The MapTiler configuration used to build map URLs, which defaults to the bundled one.
    private(set) var mapTilerConfiguration = RemotePreference(AppSettings.bundledMapTilerConfiguration)
    
    // MARK: - Presence
    
    @UserPreference(defaultValue: true)
    var sharePresence: Bool
    
    // MARK: - Feature Flags
    
    // PG_CHANGED - puts space/community feature behind a feature flag (disabled by default)
    @UserPreference(defaultValue: false)
    var spacesEnabled: Bool
    
    /// Others
    @UserPreference(defaultValue: false)
    var fuzzyRoomListSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var lowPriorityFilterEnabled: Bool
    
    /// Configuration to enable only signed device isolation mode for  crypto. In this mode only devices signed by their owner will be considered in e2ee rooms.
    @UserPreference(defaultValue: false)
    var enableOnlySignedDeviceIsolationMode: Bool
    
    @UserPreference(defaultValue: false)
    var knockingEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var threadsEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var roomThreadListEnabled: Bool
    
    @UserPreference(defaultValue: ProcessInfo().isiOSAppOnMac)
    var globalSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var focusEventOnNotificationTap: Bool
    
    @UserPreference(defaultValue: false)
    var linkPreviewsEnabled: Bool
    
    // PG_CHANGED - upstream removed liveLocationSharingEnabled; PG keeps it off by default, toggle via Developer Options only
    @UserPreference(defaultValue: false)
    var liveLocationSharingEnabled: Bool
    
    // PG_CHANGED - gates the poll form's "votes allowed per person" stepper (off by default, Developer Options only)
    @UserPreference(defaultValue: false)
    var multipleAnswerPollsEnabled: Bool
    
    /// Enables *sending* gallery messages (multiple media in a single message).
    /// Received galleries are always rendered regardless of this flag.
    @UserPreference(defaultValue: false)
    var galleryEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var jumpToReadMarkerEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var linkNewDeviceEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var automaticBackPaginationEnabled: Bool
    
    @UserPreference(key: "clientPausingAndResumingEnabledV2", defaultValue: false, volatile: true)
    var clientPausingAndResumingEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var userStatusEnabled: Bool
    
    // PG_CHANGED - do not allow enabling of developer options (build-type gated; upstream's user-toggleable developerOptionsEnabled dropped)
    let developerOptionsEnabled = AppBuildType.current.configuration == .debug || [.dev, .tst].contains(AppBuildType.current.scheme)
    
    // PG_CHANGED - puts share profile behind a feature flag (disabled by default)
    @UserPreference(defaultValue: false)
    var shareProfileEnabled: Bool
    
    // PG_CHANGED - puts invite friends behind a feature flag (disabled by default)
    @UserPreference(defaultValue: false)
    var inviteFriendsEnabled: Bool
    
    // PG_CHANGED - puts join room by address behind a feature flag (disabled by default)
    @UserPreference(defaultValue: false)
    var joinRoomByAddressEnabled: Bool
    
    // PG_CHANGED - puts room sharing behind a feature flag (disabled by default)
    @UserPreference(defaultValue: false)
    var shareRoomEnabled: Bool
    
    // PG_CHANGED - puts public room creation behind a feature flag (disabled by default)
    @UserPreference(defaultValue: false)
    var publicRoomCreationEnabled: Bool
    
    // PG_CHANGED - upstream removed the RoomDirectorySearch flag; PG keeps it off by default, toggle via Developer Options only
    @UserPreference(defaultValue: false)
    var roomDirectorySearchEnabled: Bool
    
    // PG_CHANGED
    
    // MARK: - Pg service
    
    let pgServiceUrl: String = InfoPlistReader.main.pgServiceUrl
    
    // PG_CHANGED - service message (notice banner) endpoint, configured per environment.
    let pgNoticeUrl: String = InfoPlistReader.main.pgNoticeUrl
    
    // PG_CHANGED - map tile server for the Argus brownfield bundle, configured per environment
    // and handed to the RN bundle via BrownfieldState (see PgArgusReactNativeCoordinator).
    let pgMapTileServerUrl: String = InfoPlistReader.main.pgMapTileServerUrl
    
    /// PG_CHANGED - Highest service-message id that the user has dismissed.
    /// A new message with a higher id will re-appear automatically.
    @UserPreference
    var pgDismissedServiceMessageID: Int?
    
    init(store: UserDefaultsProtocol) {
        self.store = store
    }
    
    static func volatile() -> AppSettings {
        AppSettings(store: VolatileUserDefaults())
    }
}

nonisolated extension AppSettings: CommonSettingsProtocol { }
