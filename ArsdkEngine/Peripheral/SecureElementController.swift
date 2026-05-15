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

/// Generic secure element downloader component controller
class SecureElementController: DeviceComponentController, SecureElementBackend {

    /// SecureElement component.
    var secureElement: SecureElementCore!

    /// Local url of the certificate file once downloaded
    var certificateFileUrl: URL!

    // swiftlint:disable weak_delegate
    /// Delegate to actually download the reports
    let delegate: HttpSecureElementDownloaderDelegate
    // swiftlint:enable weak_delegate

    // Whether certificate file is already present
    var certificateFilePresent: Bool {
        FileManager.default.fileExists(atPath: certificateFileUrl.path)
    }

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        self.delegate = HttpSecureElementDownloaderDelegate()
        super.init(deviceController: deviceController)
        self.secureElement = SecureElementCore(desc: Peripherals.secureElement,
                                               store: deviceController.device.peripheralStore, backend: self)

        self.certificateFileUrl = secureElement.certificateImagesStorage.workDir
            .appendingPathComponent("\(deviceController.device.uid).der")
        if certificateFilePresent {
            secureElement.update(certificateForImages: certificateFileUrl)
            secureElement.publish()
        }
    }

    /// Device is connected
    override func didConnect() {
        super.didConnect()
        delegate.configure(deviceServer: deviceController.deviceServer)
        secureElement.publish()
    }

    /// Device is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        secureElement.update(certificateCompletionStatus: .none)
        if certificateFilePresent {
            secureElement.publish()
        } else {
            secureElement.unpublish()
        }
        delegate.reset(downloader: self)
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        super.backupLinkDidActivate()
        secureElement.unpublish()
    }

    /// Drone is about to be forgotten
    override func willForget() {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: certificateFileUrl)
        } catch let err {
            ULog.e(.secureElementTag, "Error deleting certificate: \(err)")
        }
        secureElement.unpublish()
        super.willForget()
    }

    override func dataSyncAllowanceChanged(allowed: Bool) {
        if allowed && !certificateFilePresent && GroundSdkConfig.sharedInstance.enableCertificateDownload {
            downloadCertificate()
        } else {
            cancel()
        }
    }

    /// Download the certificate
    func downloadCertificate() {
        do {
            try FileManager.default.createDirectory(
                at: secureElement.certificateImagesStorage.workDir, withIntermediateDirectories: true,
                attributes: nil)
        } catch let err {
            ULog.e(.secureElementTag, "Error creating certificate folder: \(err)")
        }

        if delegate.downloadCertificateImages(destination: certificateFileUrl, downloader: self) {
            secureElement.update(certificateCompletionStatus: .started).notifyUpdated()
        }
    }

    /// Signs a challenge
    ///
    /// - Parameters:
    ///   - challenge: challenge to send
    ///   - operation: operation associated to the challenge signing request
    func sign(challenge: String, with operation: SecureElementSignatureOperation) {
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

    /// Cancels current actions
    internal func cancel() {
        delegate.cancel()
    }
}
