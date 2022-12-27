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

/// Certificate uploader for Anafi drones.
class AnafiCertificateUploader: CertificateUploaderController {

    override func upload(certificate filepath: String) -> CancelableCore? {
        certificateUploader.update(state: .uploading).notifyUpdated()

        return certificateUploaderApi?.uploadCredential(filepath: filepath, completion: { result in
            let status: CertificateUploadState
            switch result {
            case .success:
                status = .success
            case .error:
                status = .failed
            case .canceled:
                status = .canceled
            }
            self.certificateUploader.update(state: status).notifyUpdated()
        })
    }

    override func fetchSignature(completion: @escaping (String?) -> Void) {
        completion(nil)
    }

    override func fetchInfo(completion: @escaping (CertificateInfo?) -> Void) {
        completion(nil)
    }
}

/// Certificate uploader for Anafi 2 drones.
class Anafi2CertificateUploader: CertificateUploaderController {

    override func upload(certificate filepath: String) -> CancelableCore? {
        certificateUploader.update(state: .uploading).notifyUpdated()

        return certificateUploaderApi?.uploadLicense(filepath: filepath, completion: { result in
            let status: CertificateUploadState
            switch result {
            case .success:
                status = .success
            case .error:
                status = .failed
            case .canceled:
                status = .canceled
            }
            self.certificateUploader.update(state: status).notifyUpdated()
        })
    }

    override func fetchSignature(completion: @escaping (String?) -> Void) {
        _ = certificateUploaderApi?.fetchSignature(completion: { signature in completion(signature) })
    }

    override func fetchInfo(completion: @escaping (CertificateInfo?) -> Void) {
        _ = certificateUploaderApi?.fetchInfo(completion: { info in completion(info) })
    }
}

/// Base controller for certificate uploader peripheral
class CertificateUploaderController: DeviceComponentController, CertificateUploaderBackend {

    /// Certificate uploader component.
    fileprivate var certificateUploader: CertificateUploaderCore!

    /// Certificate uploader REST API.
    fileprivate var certificateUploaderApi: CertificateUploaderRestApi?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        certificateUploader = CertificateUploaderCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        if let droneServer = deviceController.deviceServer {
            certificateUploaderApi = CertificateUploaderRestApi(server: droneServer)
        }
        certificateUploader.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        certificateUploaderApi = nil
        certificateUploader.update(state: nil).unpublish()
    }

    func upload(certificate filepath: String) -> CancelableCore? {
        return nil
    }

    func fetchSignature(completion: @escaping (String?) -> Void) {
    }

    func fetchInfo(completion: @escaping (CertificateInfo?) -> Void) {
    }
}
