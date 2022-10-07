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

/// Rest api for the secure element calls to an http server.
class SecureElementRestApi {

    /// Drone server
    private let server: DeviceServer

    /// Base address to access the secure element api
    private let baseApi = "/api/v1/secure-element"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which secure element should be accessed
    init(server: DeviceServer) {
        self.server = server
    }

    /// Download the drone certificate
    ///
    /// - Parameters:
    ///   - destination: destination local file url
    ///   - completion: the completion callback (called on the main thread)
    ///   - fileUrl: url of the locally downloaded file. `nil` if there were an error during download or during copy
    /// - Returns: the request
    func downloadCertificate(
        destination: URL, completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore {

        return server.downloadFile(
            api: "\(baseApi)/drone.der",
            destination: destination,
            progress: { _ in },
            completion: { _, localFileUrl in
                completion(localFileUrl)
        })
    }

    /// Sends a challenge signing request
    ///
    /// - Parameters:
    ///   - challenge: challenge to send
    ///   - operation: operation associated to the challenge signing request
    ///   - completion: the completion callback (called on the main thread)
    ///   - token: result token
    /// - Returns: the request
    func sign(challenge: String, with operation: SecureElementSignatureOperation,
              completion: @escaping (_ token: String?) -> Void) -> CancelableCore {

        let operationStr: String
        switch operation {
        case .associate:
            operationStr = "associate"
        case .unpair_all:
            operationStr = "unpair_all"
        }

        return server.getData(api: "\(baseApi)/sign_challenge",
                              query: ["operation": operationStr, "challenge": challenge]) { result, data in
            switch result {
            case .success:
                if let data = data {
                    let tokenString = String(data: data, encoding: .utf8)
                    completion(tokenString)
                }
            default:
                completion(nil)
            }
        }
    }
}
