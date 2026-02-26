//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

#if IS_MAIN_APP
import EmbeddedElementCall
#endif

import Foundation
import SwiftUI

// Common settings between app and NSE
protocol CommonSettingsProtocol {
    var logLevel: LogLevel { get }
    var traceLogPacks: Set<TraceLogPack> { get }
    var bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> { get }
    
    var enableOnlySignedDeviceIsolationMode: Bool { get }
    var enableKeyShareOnInvite: Bool { get }
    var threadsEnabled: Bool { get }
    var hideQuietNotificationAlerts: Bool { get }
}

/// Store Element specific app settings.
final class AppSettings {
    private enum UserDefaultsKeys: String {
        case lastVersionLaunched
        case seenInvites
        case hasSeenSpacesAnnouncement
        case hasSeenNewSoundBanner
        case acknowledgedHistoryVisibleRooms
        case appLockNumberOfPINAttempts
        case appLockNumberOfBiometricAttempts
        case timelineStyle
        
        case analyticsConsentState
        case hasRunNotificationPermissionsOnboarding
        // PG_CHANGED - adds custom profile fields
        case hasRunProfileCreationOnboarding
        case hasRunIdentityConfirmationOnboarding
        
        case frequentlyUsedSystemEmojis
        
        case enableNotifications
        case enableInAppNotifications
        case pusherProfileTag
        case logLevel
        case traceLogPacks
        case viewSourceEnabled
        // PG_CHANGED - allows copyPermalink TimelineItemMenuAction only on dev builds
        case copyPermalinkEnabled
        // PG_CHANGED - allows report TimelineItemMenuAction only on dev builds
        case reportEnabled
        case optimizeMediaUploads
        case appAppearance
        case sharePresence
        
        case elementCallBaseURLOverride
        
        // Feature flags
        case publicSearchEnabled
        case fuzzyRoomListSearchEnabled
        case lowPriorityFilterEnabled
        case enableOnlySignedDeviceIsolationMode
        case enableKeyShareOnInvite
        case knockingEnabled
        case threadsEnabled
        case developerOptionsEnabled
        case linkPreviewsEnabled
        case focusEventOnNotificationTap
        case linkNewDeviceEnabled
        // PG_CHANGED - puts translate TimelineItemMenuAction behind a feature flag (disabled by default)
        case translateEnabled
        // PG_CHANGED - puts share profile behind a feature flag (disabled by default)
        case shareProfileEnabled
        // PG_CHANGED - puts invite friends behind a feature flag (disabled by default)
        case inviteFriendsEnabled
        // PG_CHANGED - puts join room by address behind a feature flag (disabled by default)
        case joinRoomByAddressEnabled
        // PG_CHANGED - puts room sharing behind a feature flag (disabled by default)
        case shareRoomEnabled
        // PG_CHANGED - puts public room creation behind a feature flag (disabled by default)
        case publicRoomCreationEnabled
        
        // PG_CHANGED - puts space/community feature behind a feature flag (disabled by default)
        case spacesEnabled
        
        // Spaces
        case spaceSettingsEnabled
        case createSpaceEnabled
        
        // Doug's tweaks 🔧
        case hideUnreadMessagesBadge
        case hideQuietNotificationAlerts
    }
    
    private static var suiteName: String = InfoPlistReader.main.appGroupIdentifier

    /// UserDefaults to be used on reads and writes.
    private static var store: UserDefaults! = UserDefaults(suiteName: suiteName)
    
    // PG_CHANGED - TO REMOVE: Force disable Threads for users who previously enabled it
    init() {
        let migrationKey = "pgThreadsLabsMigrationDone"
        if Self.store.bool(forKey: UserDefaultsKeys.threadsEnabled.rawValue), !Self.store.bool(forKey: migrationKey) {
            Self.store.removeObject(forKey: UserDefaultsKeys.threadsEnabled.rawValue)
            Self.store.set(true, forKey: migrationKey)
        }
    }

    // PG_CHANGED - TO REMOVE - END

    /// Whether or not the app is a development build that isn't in production.
    static var isDevelopmentBuild: Bool = {
        #if DEBUG
        true
        #else
        // PG_CHANGED - considers dev and tst app builds as dev builds
        let apps = ["be.bsc.app.dev", "be.bsc.app.tst"]
        return apps.contains(InfoPlistReader.main.baseBundleIdentifier)
        #endif
    }()
        
    static func resetAllSettings() {
        MXLog.warning("Resetting the AppSettings.")
        store.removePersistentDomain(forName: suiteName)
    }
    
    static func resetSessionSpecificSettings() {
        MXLog.warning("Resetting the user session specific AppSettings.")
        store.removeObject(forKey: UserDefaultsKeys.hasRunIdentityConfirmationOnboarding.rawValue)
        // PG_CHANGED - removes profile creation onboarding preference
        store.removeObject(forKey: UserDefaultsKeys.hasRunProfileCreationOnboarding.rawValue)
    }
    
    static func configureWithSuiteName(_ name: String) {
        suiteName = name
        
        guard let userDefaults = UserDefaults(suiteName: name) else {
            fatalError("Fail to load shared UserDefaults")
        }
        
        store = userDefaults
    }
    
    // MARK: - Hooks
    
    // swiftlint:disable:next function_parameter_count
    func override(accountProviders: [String],
                  allowOtherAccountProviders: Bool,
                  hideBrandChrome: Bool,
                  pushGatewayBaseURL: URL,
                  oidcRedirectURL: URL,
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
        self.oidcRedirectURL = oidcRedirectURL
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
        self.mapTilerConfiguration = mapTilerConfiguration
    }
    
    // MARK: - Application
    
    /// The last known version of the app that was launched on this device, which is
    /// used to detect when migrations should be run. When `nil` the app may have been
    /// deleted between runs so should clear data in the shared container and keychain.
    @UserPreference(key: UserDefaultsKeys.lastVersionLaunched, storageType: .userDefaults(store))
    var lastVersionLaunched: String?
        
    /// The Set of room identifiers of invites that the user already saw in the invites list.
    /// This Set is being used to implement badges for unread invites.
    @UserPreference(key: UserDefaultsKeys.seenInvites, defaultValue: [], storageType: .userDefaults(store))
    var seenInvites: Set<String>
    
    @UserPreference(key: UserDefaultsKeys.hasSeenSpacesAnnouncement, defaultValue: false, storageType: .userDefaults(store))
    var hasSeenSpacesAnnouncement
    
    /// Defaults to `true` for new users, and we use a migration to set it to `false` for existing users.
    @UserPreference(key: UserDefaultsKeys.hasSeenNewSoundBanner, defaultValue: true, storageType: .userDefaults(store))
    var hasSeenNewSoundBanner
    
    /// The Set of room identifiers that the user has acknowledged have visible history.
    @UserPreference(key: UserDefaultsKeys.acknowledgedHistoryVisibleRooms, defaultValue: [], storageType: .userDefaults(store))
    var acknowledgedHistoryVisibleRooms: Set<String>
    
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
    private(set) var historySharingDetailsURL: URL = AppSettings.beamURL("/help#e2ee-history-sharing")
    
    @UserPreference(key: UserDefaultsKeys.appAppearance, defaultValue: .system, storageType: .userDefaults(store))
    var appAppearance: AppAppearance
    
    // MARK: - Security

    /// PG_CHANGED: The PIN is mandatory only if the OS does not have a lock set up.
    /// The app must be locked with a PIN code as part of the authentication flow.
    let appLockIsMandatory = true
    /// The amount of time the app can remain in the background for without requesting the PIN/TouchID/FaceID.
    let appLockGracePeriod: TimeInterval = 2
    /// Any codes that the user isn't allowed to use for their PIN.
    let appLockPINCodeBlockList = ["0000", "1234"]
    /// The number of attempts the user has made to unlock the app with a PIN code (resets when unlocked).
    @UserPreference(key: UserDefaultsKeys.appLockNumberOfPINAttempts, defaultValue: 0, storageType: .userDefaults(store))
    var appLockNumberOfPINAttempts: Int
    
    // MARK: - Authentication
    
    /// Any pre-defined static client registrations for OIDC issuers.
    let oidcStaticRegistrations: [URL: String] = [:]
    /// The redirect URL used for OIDC. This no longer uses universal links so we don't need the bundle ID to avoid conflicts between Element X, Nightly and PR builds.
    /// PG_CHANGED
    private(set) var oidcRedirectURL = URL(string: InfoPlistReader.main.oidcRedirectURL) ?? { fatalError("Invalid OIDC redirect URL") }()
    
    private(set) lazy var oidcConfiguration = OIDCConfiguration(clientName: InfoPlistReader.main.bundleDisplayName,
                                                                redirectURI: oidcRedirectURL,
                                                                clientURI: websiteURL,
                                                                logoURI: logoURL,
                                                                tosURI: acceptableUseURL,
                                                                policyURI: privacyURL,
                                                                staticRegistrations: oidcStaticRegistrations.mapKeys { $0.absoluteString })
    
    /// Whether or not the Create Account button is shown on the start screen.
    ///
    /// **Note:** Setting this to false doesn't prevent someone from creating an account when the selected homeserver's MAS allows registration.
    /// PG_CHANGED
    let showCreateAccountButton = false
    
    // MARK: - Notifications
    
    // PG_CHANGED
    var pusherAppID = InfoPlistReader.main.baseBundleIdentifier + ".ios"
    
    // PG_CHANGED
    private(set) var pushGatewayBaseURL = URL(string: InfoPlistReader.main.pushGatewayBaseURL) ?? { fatalError("Invalid pushGatewayBaseURL") }()
    var pushGatewayNotifyEndpoint: URL { pushGatewayBaseURL.appending(path: "_matrix/push/v1/notify") }
    
    @UserPreference(key: UserDefaultsKeys.enableNotifications, defaultValue: true, storageType: .userDefaults(store))
    var enableNotifications

    @UserPreference(key: UserDefaultsKeys.enableInAppNotifications, defaultValue: true, storageType: .userDefaults(store))
    var enableInAppNotifications
    
    @UserPreference(key: UserDefaultsKeys.hideQuietNotificationAlerts, defaultValue: false, storageType: .userDefaults(store))
    var hideQuietNotificationAlerts

    /// Tag describing which set of device specific rules a pusher executes.
    @UserPreference(key: UserDefaultsKeys.pusherProfileTag, storageType: .userDefaults(store))
    var pusherProfileTag: String?
    
    // MARK: - Logging
        
    @UserPreference(key: UserDefaultsKeys.logLevel, defaultValue: LogLevel.info, storageType: .userDefaults(store))
    var logLevel
    
    @UserPreference(key: UserDefaultsKeys.traceLogPacks, defaultValue: [], storageType: .userDefaults(store))
    var traceLogPacks: Set<TraceLogPack>
    
    // MARK: - Bug report
    
    // PG_CHANGED
    let bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> = .init(.url(URL(string: InfoPlistReader.main.bugReportRageshakeURL) ?? { fatalError("Invalid bugReportRageshakeURL") }()))
    let bugReportSentryURL: URL? = Secrets.sentryDSN.flatMap { URL(string: $0) }
    let bugReportSentryRustURL: URL? = Secrets.sentryRustDSN.flatMap { URL(string: $0) }

    // PG_CHANGED - sets the rageshake application ID as the bundle identifier + .ios
    /// The name allocated by the bug report server
    private(set) var bugReportApplicationID = InfoPlistReader.main.baseBundleIdentifier + ".ios"
    /// The maximum size of the upload request. Default value is just below CloudFlare's max request size.
    let bugReportMaxUploadSize = 50 * 1024 * 1024
    
    // MARK: - Analytics
    
    /// The configuration to use for analytics. Set to `nil` to disable analytics.
    let analyticsConfiguration: AnalyticsConfiguration? = AppSettings.makeAnalyticsConfiguration()
    // PG_CHANGED - replaces element.io web URLs references by beam.belgium.be
    /// The URL to open with more information about analytics terms. When this is `nil` the "Learn more" link will be hidden.
    private(set) var analyticsTermsURL: URL? = AppSettings.beamURL("/cookie-policy")
    /// Whether or not there the app is able ask for user consent to enable analytics or sentry reporting.
    var canPromptForAnalytics: Bool { analyticsConfiguration != nil || bugReportSentryURL != nil }
    
    private static func makeAnalyticsConfiguration() -> AnalyticsConfiguration? {
        guard let host = Secrets.postHogHost, let apiKey = Secrets.postHogAPIKey else { return nil }
        return AnalyticsConfiguration(host: host, apiKey: apiKey)
    }
    
    /// Whether the user has opted in to send analytics.
    @UserPreference(key: UserDefaultsKeys.analyticsConsentState, defaultValue: AnalyticsConsentState.unknown, storageType: .userDefaults(store))
    var analyticsConsentState
    
    @UserPreference(key: UserDefaultsKeys.hasRunNotificationPermissionsOnboarding, defaultValue: false, storageType: .userDefaults(store))
    var hasRunNotificationPermissionsOnboarding
    
    // PG_CHANGED - adds custom profile fields
    @UserPreference(key: UserDefaultsKeys.hasRunProfileCreationOnboarding, defaultValue: false, storageType: .userDefaults(store))
    var hasRunProfileCreationOnboarding
    
    @UserPreference(key: UserDefaultsKeys.hasRunIdentityConfirmationOnboarding, defaultValue: false, storageType: .userDefaults(store))
    var hasRunIdentityConfirmationOnboarding
    
    @UserPreference(key: UserDefaultsKeys.frequentlyUsedSystemEmojis, defaultValue: [FrequentlyUsedEmoji](), storageType: .userDefaults(store))
    var frequentlyUsedSystemEmojis
    
    // MARK: - Home Screen
    
    @UserPreference(key: UserDefaultsKeys.hideUnreadMessagesBadge, defaultValue: false, storageType: .userDefaults(store))
    var hideUnreadMessagesBadge
    
    // MARK: - Room Screen
    
    // PG_CHANGED - allows viewSource TimelineItemMenuAction only on dev builds
    @UserPreference(key: UserDefaultsKeys.viewSourceEnabled, defaultValue: false, storageType: .userDefaults(store))
    var viewSourceEnabled

    // PG_CHANGED - allows copyPermalink TimelineItemMenuAction only on dev builds
    @UserPreference(key: UserDefaultsKeys.copyPermalinkEnabled, defaultValue: false, storageType: .userDefaults(store))
    var copyPermalinkEnabled

    // PG_CHANGED - allows report TimelineItemMenuAction only on dev builds
    @UserPreference(key: UserDefaultsKeys.reportEnabled, defaultValue: false, storageType: .userDefaults(store))
    var reportEnabled
    
    // PG_CHANGED - puts translate TimelineItemMenuAction behind a feature flag (disabled by default)
    @UserPreference(key: UserDefaultsKeys.translateEnabled, defaultValue: false, storageType: .userDefaults(store))
    var translateEnabled

    @UserPreference(key: UserDefaultsKeys.optimizeMediaUploads, defaultValue: true, storageType: .userDefaults(store))
    var optimizeMediaUploads
    
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
    
    @UserPreference(key: UserDefaultsKeys.elementCallBaseURLOverride, defaultValue: nil, storageType: .userDefaults(store))
    var elementCallBaseURLOverride: URL?
    
    // MARK: - Users
    
    /// Whether to hide the display name and avatar of ignored users as these may contain objectionable content.
    let hideIgnoredUserProfiles = true
    
    // MARK: - Maps
    
    // maptiler base url
    private(set) var mapTilerConfiguration = MapTilerConfiguration(baseURL: "https://api.maptiler.com/maps",
                                                                   apiKey: Secrets.mapLibreAPIKey,
                                                                   lightStyleID: "9bc819c8-e627-474a-a348-ec144fe3d810",
                                                                   darkStyleID: "dea61faf-292b-4774-9660-58fcef89a7f3")
    
    // MARK: - Presence
    
    @UserPreference(key: UserDefaultsKeys.sharePresence, defaultValue: true, storageType: .userDefaults(store))
    var sharePresence
    
    // MARK: - Feature Flags
    
    // PG_CHANGED - puts space/community feature behind a feature flag (disabled by default)
    @UserPreference(key: UserDefaultsKeys.spacesEnabled, defaultValue: false, storageType: .userDefaults(store))
    var spacesEnabled
    
    // Spaces
    @UserPreference(key: UserDefaultsKeys.spaceSettingsEnabled, defaultValue: false, storageType: .userDefaults(store))
    var spaceSettingsEnabled
    
    @UserPreference(key: UserDefaultsKeys.createSpaceEnabled, defaultValue: false, storageType: .userDefaults(store))
    var createSpaceEnabled
    
    // Others
    @UserPreference(key: UserDefaultsKeys.publicSearchEnabled, defaultValue: false, storageType: .userDefaults(store))
    var publicSearchEnabled
    
    @UserPreference(key: UserDefaultsKeys.fuzzyRoomListSearchEnabled, defaultValue: false, storageType: .userDefaults(store))
    var fuzzyRoomListSearchEnabled
    
    @UserPreference(key: UserDefaultsKeys.lowPriorityFilterEnabled, defaultValue: false, storageType: .userDefaults(store))
    var lowPriorityFilterEnabled
    
    /// Configuration to enable only signed device isolation mode for  crypto. In this mode only devices signed by their owner will be considered in e2ee rooms.
    @UserPreference(key: UserDefaultsKeys.enableOnlySignedDeviceIsolationMode, defaultValue: false, storageType: .userDefaults(store))
    var enableOnlySignedDeviceIsolationMode
    
    /// Configuration to enable encrypted history sharing on invite, and accepting keys from inviters.
    @UserPreference(key: UserDefaultsKeys.enableKeyShareOnInvite, defaultValue: false, storageType: .userDefaults(store))
    var enableKeyShareOnInvite
    
    @UserPreference(key: UserDefaultsKeys.knockingEnabled, defaultValue: false, storageType: .userDefaults(store))
    var knockingEnabled
    
    @UserPreference(key: UserDefaultsKeys.threadsEnabled, defaultValue: false, storageType: .userDefaults(store))
    var threadsEnabled
    
    @UserPreference(key: UserDefaultsKeys.focusEventOnNotificationTap, defaultValue: false, storageType: .userDefaults(store))
    var focusEventOnNotificationTap
        
    @UserPreference(key: UserDefaultsKeys.linkPreviewsEnabled, defaultValue: false, storageType: .userDefaults(store))
    var linkPreviewsEnabled
    
    @UserPreference(key: UserDefaultsKeys.linkNewDeviceEnabled, defaultValue: false, storageType: .userDefaults(store))
    var linkNewDeviceEnabled
    
    // PG_CHANGED - do not allow enabling of developer options
    let developerOptionsEnabled = isDevelopmentBuild

    // PG_CHANGED - puts share profile behind a feature flag (disabled by default)
    @UserPreference(key: UserDefaultsKeys.shareProfileEnabled, defaultValue: false, storageType: .userDefaults(store))
    var shareProfileEnabled

    // PG_CHANGED - puts invite friends behind a feature flag (disabled by default)
    @UserPreference(key: UserDefaultsKeys.inviteFriendsEnabled, defaultValue: false, storageType: .userDefaults(store))
    var inviteFriendsEnabled

    // PG_CHANGED - puts join room by address behind a feature flag (disabled by default)
    @UserPreference(key: UserDefaultsKeys.joinRoomByAddressEnabled, defaultValue: false, storageType: .userDefaults(store))
    var joinRoomByAddressEnabled

    // PG_CHANGED - puts room sharing behind a feature flag (disabled by default)
    @UserPreference(key: UserDefaultsKeys.shareRoomEnabled, defaultValue: false, storageType: .userDefaults(store))
    var shareRoomEnabled

    // PG_CHANGED - puts public room creation behind a feature flag (disabled by default)
    @UserPreference(key: UserDefaultsKeys.publicRoomCreationEnabled, defaultValue: false, storageType: .userDefaults(store))
    var publicRoomCreationEnabled

    // PG_CHANGED

    // MARK: - Pg service

    let pgServiceUrl: String = InfoPlistReader.main.pgServiceUrl
}

extension AppSettings: CommonSettingsProtocol { }
