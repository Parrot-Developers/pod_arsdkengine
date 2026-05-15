// Copyright (C) 2025 Parrot Drones SAS
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions
//    are met:
//    * Redistributions of source code must retain the above copyright
//      notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above copyright
//      notice, this list of conditions and the following disclaimer in
//      the documentation and/or other materials provided with the
//      distribution.
//    * Neither the name of the Parrot Company nor the names
//      of its contributors may be used to endorse or promote products
//      derived from this software without specific prior written
//      permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//    PARROT COMPANY BE LIABLE FOR ANY DIRECT, INDIRECT,
//    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
//    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
//    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
//    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
//    SUCH DAMAGE.

import Foundation
import GroundSdk

/// Remote antenna secure element downloader component controller
class RaSecureElementController: DeviceComponentController, SecureElementBackend {
    /// SecureElement component.
    var secureElement: SecureElementCore!

    /// Secure element REST Api.
    /// Not nil when secure element has been configured. Nil after a reset.
    private var secureElementApi: SecureElementRestApi?

    // swiftlint:disable weak_delegate
    /// Delegate to actually download the reports
    let delegate: HttpSecureElementDownloaderDelegate
    // swiftlint:enable weak_delegate

    /// Current secure element download request
    /// - Note: this request can change during the overall download task .
    private var certificateRequest: CancelableCore?

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        self.delegate = HttpSecureElementDownloaderDelegate()
        super.init(deviceController: deviceController)
        self.secureElement = SecureElementCore(desc: Peripherals.remoteAntennaSecureElement,
                                               store: deviceController.device.peripheralStore, backend: self)
    }

    override func remoteAntennaDidConnect() {
        retrieveCertificate()
        secureElement.publish()
    }

    override func remoteAntennaDidDisconnect() {
        delegate.cancel()
        certificateRequest?.cancel()
        certificateRequest = nil
        secureElement.unpublish()
    }

    /// Retrieves device certificate.
    private func retrieveCertificate() {
        let certificateFileUrl: URL = secureElement.certificateImagesStorage.workDir
            .appendingPathComponent("\(deviceController.device.uid).der")

        if FileManager.default.fileExists(atPath: certificateFileUrl.path) {
            secureElement.update(certificateForImages: certificateFileUrl).notifyUpdated()
        } else {
            downloadCertificate(certificateFile: certificateFileUrl)
        }
    }

    /// Downloads device's certificate.
    ///
    /// - Parameter certificateFile: destination of the certificate file
    private func downloadCertificate(certificateFile: URL) {
        guard certificateRequest == nil else { return }
        certificateRequest = secureElementApi?.downloadCertificate(
            destination: certificateFile,
            completion: { certificateUrl in
                if let certificateUrl {
                    self.secureElement
                        .update(certificateForImages: certificateUrl)
                        .notifyUpdated()
                }
                self.certificateRequest = nil
            })
    }

    /// Signs a challenge
    ///
    /// - Parameters:
    ///   - challenge: challenge to send
    ///   - operation: operation associated to the challenge signing request
    func sign(challenge: String, with operation: SecureElementSignatureOperation) {
        if let raDeviceServer = (deviceController as? RCController)?.remoteAntenna?.deviceServer {
            delegate.configure(deviceServer: raDeviceServer)
            let result = delegate.sign(challenge: challenge, with: operation) { token in
                if let token = token {
                    self.secureElement.update(
                        newChallengeState: .success(challenge: challenge, token: token)).notifyUpdated()
                } else {
                    self.secureElement.update(newChallengeState: .failure(challenge: challenge)).notifyUpdated()
                }
            }
            if result {
                secureElement.update(newChallengeState: .processing(challenge: challenge))
                    .notifyUpdated()
            }
        }
    }

    func cancel() {
        // nothing to do
    }
}
