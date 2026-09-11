//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-06-06

import Combine
import SwiftUI

// PG_CHANGED - integrates Expo Brownfield
import PGArgusMobileBrownfield

enum AppDelegateCallback {
    case registeredNotifications(deviceToken: Data)
    case failedToRegisteredNotifications(error: Error)
}

final class AppDelegate: ExpoBrownfieldAppDelegate {
    let callbacks = PassthroughSubject<AppDelegateCallback, Never>()
    var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Add a SceneDelegate to the SwiftUI scene so that we can connect up the WindowManager.
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NSTextAttachment.registerViewProviderClass(PillAttachmentViewProvider.self, forFileType: InfoPlistReader.main.pillsUTType)
        
        let didFinishLaunching = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        // PG_CHANGED - integrates Expo Brownfield
        ReactNativeHostManager.shared.initialize()
        
        return didFinishLaunching
    }
    
    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        callbacks.send(.registeredNotifications(deviceToken: deviceToken))
    }
    
    override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
        callbacks.send(.failedToRegisteredNotifications(error: error))
    }
    
    override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        let expoOrientations = super.application(application, supportedInterfaceOrientationsFor: window)
        let supportedOrientations = orientationLock.intersection(expoOrientations)
        return supportedOrientations.isEmpty ? orientationLock : supportedOrientations
    }
}
