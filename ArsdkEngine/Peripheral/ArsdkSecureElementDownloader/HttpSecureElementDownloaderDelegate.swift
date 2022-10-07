// Copyright (C) 2020 Parrot Drones SAS
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

/// Secure element delegate that does the download through http
class HttpSecureElementDownloaderDelegate: ArsdkSecureElementDownloaderDelegate {

    /// Secure element REST Api.
    /// Not nil when secure element has been configured. Nil after a reset.
    private var secureElementApi: SecureElementRestApi?

    /// Current secure element download request
    /// - Note: this request can change during the overall download task .
    private var currentRequestForSign: CancelableCore?

    /// Current secure element download request
    /// - Note: this request can change during the overall download task .
    private var currentRequestForImg: CancelableCore?

    func configure(downloader: SecureElementController) {
        if let droneServer = downloader.deviceController.deviceServer {
            secureElementApi = SecureElementRestApi(server: droneServer)
        }
    }

    func reset(downloader: SecureElementController) {
        secureElementApi = nil
    }

    func sign(challenge: String, with operation: SecureElementSignatureOperation,
              downloader: SecureElementController) -> Bool {
        guard currentRequestForSign == nil else {
            return false
        }

        currentRequestForSign = secureElementApi?.sign(challenge: challenge, with: operation, completion: { token in
            if let token = token {
                downloader.secureElement.update(
                    newChallengeState: .success(challenge: challenge, token: token)).notifyUpdated()
            } else {
                downloader.secureElement.update(newChallengeState: .failure(challenge: challenge)).notifyUpdated()
            }
            self.currentRequestForSign = nil
        })

        return currentRequestForSign != nil
    }

    func downloadCertificateImages(destination: URL, downloader: SecureElementController) -> Bool {
        guard currentRequestForImg == nil else {
            return false
        }

        currentRequestForImg = secureElementApi?.downloadCertificate(
            destination: destination,
            completion: { certificateUrl in
                if let certificateUrl = certificateUrl {
                    downloader.secureElement
                        .update(certificateCompletionStatus: .success)
                        .update(certificateForImages: certificateUrl)
                        .notifyUpdated()
                } else {
                    downloader.secureElement
                        .update(certificateCompletionStatus: .failed)
                        .notifyUpdated()
                }
                self.currentRequestForImg = nil
        })

        return currentRequestForImg != nil
    }

    func cancel() {
        currentRequestForImg?.cancel()
        currentRequestForSign?.cancel()
    }
}
