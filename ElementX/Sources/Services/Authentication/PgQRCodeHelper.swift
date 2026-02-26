//
// Shared helpers for QR code login/reciprocation flows.
//

import Foundation
import MatrixRustSDK

enum PgQRCodeHelper {
    enum Mode {
        static let login: UInt8 = 0x03
        static let reciprocate: UInt8 = 0x04
    }
    
    /// Map HumanQrLoginError into AuthenticationServiceError consistently across services.
    static func mapHumanError(_ error: HumanQrLoginError) -> AuthenticationServiceError {
        switch error {
        case .Cancelled:
            return .qrCodeError(.cancelled)
        case .ConnectionInsecure:
            return .qrCodeError(.connectionInsecure)
        case .Declined:
            return .qrCodeError(.declined)
        case .LinkingNotSupported:
            return .qrCodeError(.linkingNotSupported)
        case .Expired:
            return .qrCodeError(.expired)
        case .SlidingSyncNotAvailable:
            return .qrCodeError(.deviceNotSupported)
        case .OtherDeviceNotSignedIn:
            return .qrCodeError(.deviceNotSignedIn)
        case .Unknown, .NotFound, .OidcMetadataInvalid, .CheckCodeAlreadySent, .CheckCodeCannotBeSent, .Network:
            return .qrCodeError(.unknown)
        }
    }
}
