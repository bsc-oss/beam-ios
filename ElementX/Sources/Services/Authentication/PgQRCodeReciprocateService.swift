//
// Copyright 2026 Belgian Secure Communications (BSC)
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK

/// A QR code service that performs the reciprocation flow using the existing signed-in session.
/// It conforms to QRCodeLoginServiceProtocol so it can be used by the existing QRCodeLogin screen.
public final class PgQRCodeReciprocateService: QRCodeLoginServiceProtocol {
    private let userSession: UserSessionProtocol
    private let clientProxy: ClientProxyProtocol
    
    init(userSession: UserSessionProtocol) {
        self.userSession = userSession
        clientProxy = userSession.clientProxy
    }
    
    /// In the reciprocation flow, scanning a QR should be a Login QR (mode 0x03).
    /// We call the SDK's reciprocation APIs using the current session's client.
    func loginWithQRCode(data: Data) -> QRLoginProgressPublisher {
        let progressSubject = CurrentValueSubject<QRLoginProgress, AuthenticationServiceError>(.starting)
        
        let qrData: QrCodeData
        do {
            qrData = try QrCodeData.fromBytes(bytes: data)
        } catch {
            MXLog.error("QRCode decode error: \(error)")
            progressSubject.send(completion: .failure(.qrCodeError(.invalidQRCode)))
            return progressSubject.asCurrentValuePublisher()
        }
        
        guard qrData.mode() == PgQRCodeHelper.Mode.login else {
            MXLog.error("Expected Login mode (0x03) for reciprocation, got mode: \(qrData.mode())")
            progressSubject.send(completion: .failure(.qrCodeError(.linkingNotSupported)))
            return progressSubject.asCurrentValuePublisher()
        }
        
        let listener = SDKListener { progress in
            guard let progress = QRLoginProgress(rustProgress: progress) else { return }
            progressSubject.send(progress)
        }
        
        Task { [weak self] in
            guard let self else { return }
            
            switch await clientProxy.reciprocateWithQrCode(qrCodeData: qrData, progressListener: listener) {
            case .success:
                progressSubject.send(.signedIn(userSession))
            case .failure(.sdkError(let error as HumanQrLoginError)):
                MXLog.error("QRCode reciprocation error: \(error)")
                progressSubject.send(completion: .failure(PgQRCodeHelper.mapHumanError(error)))
            case .failure(let error):
                MXLog.error("QRCode reciprocation unknown error: \(error)")
                progressSubject.send(completion: .failure(.qrCodeError(.unknown)))
            }
        }
        
        return progressSubject.asCurrentValuePublisher()
    }
    
    /// The QR reciprocation flow requires resuming after the browser is closed.
    func resumeReciprocation() async {
        do {
            try await clientProxy.resumeQrReciprocation().get()
        } catch {
            MXLog.error("Failed resuming QR reciprocation: \(error)")
        }
    }
}
