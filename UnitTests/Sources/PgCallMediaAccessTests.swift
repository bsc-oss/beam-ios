//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
@testable import ElementX
import Foundation
import Testing

@MainActor
struct PgCallMediaAccessTests {
    @Test
    func deniedMicrophonePointsToTheSettings() throws {
        let appMediator = AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .denied))
        let viewModel = makeViewModel(appMediator: appMediator)
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone"]))
        
        let alertInfo = try #require(viewModel.context.alertInfo)
        #expect(alertInfo.title == L10n.commonPermission)
        #expect(alertInfo.message == L10n.dialogPermissionMicrophone)
        #expect(alertInfo.primaryButton.title == L10n.actionOpenSettings)
        #expect(alertInfo.secondaryButton?.title == L10n.actionNotNow)
        
        alertInfo.primaryButton.action?()
        #expect(appMediator.openAppSettingsCallsCount == 1)
    }
    
    @Test
    func refusalAnsweringTheSystemPromptPointsToTheSettings() {
        let appMediator = AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .notDetermined))
        let viewModel = makeViewModel(appMediator: appMediator)
        // The user taps "Don't Allow" in the system prompt, which iOS never shows again.
        appMediator.mediaCaptureAuthorizationStatusForReturnValue = .denied
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone"]))
        
        #expect(viewModel.context.alertInfo?.message == L10n.dialogPermissionMicrophone)
    }
    
    @Test
    func repeatedReportsOfOneRefusalShowOneDialog() {
        // pg-call reports a refusal once per code path waiting on the request.
        let viewModel = makeViewModel(appMediator: AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .denied)))
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone"]))
        let shownAlertID = viewModel.context.alertInfo?.id
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone"]))
        
        #expect(shownAlertID != nil)
        #expect(viewModel.context.alertInfo?.id == shownAlertID)
    }
    
    @Test
    func restrictedCameraPointsToTheSettings() {
        let viewModel = makeViewModel(appMediator: AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .restricted)))
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["camera"]))
        
        #expect(viewModel.context.alertInfo?.message == L10n.dialogPermissionCamera)
    }
    
    @Test
    func namesTheMicrophoneWhenBothAreBlocked() {
        let viewModel = makeViewModel(appMediator: AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .denied)))
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone", "camera"]))
        
        #expect(viewModel.context.alertInfo?.message == L10n.dialogPermissionMicrophone)
    }
    
    @Test
    func namesOnlyTheBlockedDevice() {
        let appMediator = AppMediatorMock(.init())
        appMediator.mediaCaptureAuthorizationStatusForClosure = { $0 == .video ? .denied : .authorized }
        let viewModel = makeViewModel(appMediator: appMediator)
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone", "camera"]))
        
        #expect(viewModel.context.alertInfo?.message == L10n.dialogPermissionCamera)
    }
    
    @Test
    func refusalOfAnAllowedDeviceShowsNothing() {
        // The settings can't help when WebKit refuses on its own.
        let viewModel = makeViewModel(appMediator: AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .authorized)))
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone", "camera"]))
        
        #expect(viewModel.context.alertInfo == nil)
    }
    
    @Test
    func unknownKindsShowNothing() {
        let viewModel = makeViewModel(appMediator: AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .denied)))
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["screen"]))
        
        #expect(viewModel.context.alertInfo == nil)
    }
    
    @Test
    func keepsAnAlertAlreadyShown() {
        let viewModel = makeViewModel(appMediator: AppMediatorMock(.init(mediaCaptureAuthorizationStatus: .denied)))
        let shownAlertID = UUID()
        viewModel.context.alertInfo = AlertInfo(id: shownAlertID, title: L10n.commonError)
        
        viewModel.context.send(viewAction: .mediaAccessRefused(requestedKinds: ["microphone"]))
        
        #expect(viewModel.context.alertInfo?.id == shownAlertID)
    }
    
    // MARK: - Helpers
    
    private func makeViewModel(appMediator: AppMediatorMock) -> CallScreenViewModel {
        let clientProxy = ClientProxyMock(.init(deviceID: "call-device-id"))
        
        let widgetDriver = ElementCallWidgetDriverMock()
        widgetDriver.messagePublisher = .init()
        widgetDriver.actions = PassthroughSubject<ElementCallWidgetDriverAction, Never>().eraseToAnyPublisher()
        widgetDriver.startBaseURLClientIDColorSchemeVoiceOnlyRageshakeURLAnalyticsConfigurationReturnValue = .success(URL.userDirectory)
        
        let roomProxy = JoinedRoomProxyMock(.init())
        roomProxy.elementCallWidgetDriverDeviceIDReturnValue = widgetDriver
        
        return CallScreenViewModel(elementCallService: ElementCallServiceMock(.init()),
                                   configuration: .init(roomProxy: roomProxy,
                                                        clientProxy: clientProxy,
                                                        clientID: "io.element.elementx",
                                                        elementCallBaseURL: "https://call.element.io",
                                                        elementCallBaseURLOverride: nil,
                                                        voiceOnly: false,
                                                        colorScheme: .light),
                                   allowPictureInPicture: false,
                                   appSettings: .volatile(),
                                   analyticsService: AnalyticsServiceMock(.init()),
                                   appMediator: appMediator)
    }
}
