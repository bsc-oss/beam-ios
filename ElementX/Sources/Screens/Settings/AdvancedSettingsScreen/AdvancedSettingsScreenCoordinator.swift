//
// Copyright 2026 Belgian Secure Communications (BSC)
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//
//
// Modified by Belgian Secure Communications for Beam application on 2026-06-06

import Combine
import SwiftUI

struct AdvancedSettingsScreenCoordinatorParameters {
    let appSettings: AppSettings
    let analytics: AnalyticsService
    let clientProxy: ClientProxyProtocol
    let userIndicatorController: UserIndicatorControllerProtocol
}

final class AdvancedSettingsScreenCoordinator: CoordinatorProtocol {
    private var viewModel: AdvancedSettingsScreenViewModelProtocol
    
    init(parameters: AdvancedSettingsScreenCoordinatorParameters) {
        viewModel = AdvancedSettingsScreenViewModel(advancedSettings: parameters.appSettings,
                                                    analytics: parameters.analytics,
                                                    clientProxy: parameters.clientProxy,
                                                    userIndicatorController: parameters.userIndicatorController,
                                                    appSettings: parameters.appSettings) // PG_CHANGED - inject appSettings (ServiceLocator removed)
    }
            
    func toPresentable() -> AnyView {
        AnyView(AdvancedSettingsScreen(context: viewModel.context))
    }
}
