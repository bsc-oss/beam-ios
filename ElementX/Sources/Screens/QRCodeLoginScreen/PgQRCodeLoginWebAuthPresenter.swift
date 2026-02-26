import AuthenticationServices

/// Presents a web authentication session for QR code login reciprocation flow.
///
/// A web authentication session is used so that the user can complete the login verification (=giving consent)
/// in their browser with the same session used during initial authentication.
@MainActor
class PgQRCodeLoginWebAuthPresenter: NSObject {
    private let presentationAnchor: UIWindow
    private var webAuthSession: ASWebAuthenticationSession?
    
    init(presentationAnchor: UIWindow) {
        self.presentationAnchor = presentationAnchor
        super.init()
    }
    
    enum Result {
        case completed
        case cancelledByUser
    }
    
    /// Presents a web authentication session for the verification URL.
    /// - Parameters:
    ///   - verificationURL: The URL to open for verification
    ///   - completion: Called when the session completes or is cancelled, with the result
    func start(verificationURL: URL, completion: @escaping (Result) -> Void) {
        let session = ASWebAuthenticationSession(url: verificationURL, callbackURLScheme: nil) { [weak self] _, error in
            guard let self else { return }
            defer {
                self.webAuthSession = nil
            }
            
            if let asError = error as? ASWebAuthenticationSessionError {
                switch asError.code {
                // TODO: handle this later, when more prio tasks are done
//                case .canceledLogin:
//                    MXLog.info("User cancelled Web Authentication Session")
//                    completion(.cancelledByUser)
//                    return
                default:
                    MXLog.error("Web Authentication Session error: \(asError)")
                }
            }
            
            completion(.completed)
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.additionalHeaderFields = [
            // PG_CHANGED
            "X-Beam-User-Agent": UserAgentBuilder.makeASCIIUserAgent()
        ]
        webAuthSession = session
        
        guard session.start() else {
            MXLog.error("Failed to start Web Authentication Session")
            webAuthSession = nil
            completion(.completed)
            return
        }
    }
    
    /// Cancels the current web authentication session if one is in progress.
    func cancel() {
        webAuthSession?.cancel()
        webAuthSession = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension PgQRCodeLoginWebAuthPresenter: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchor
    }
}
