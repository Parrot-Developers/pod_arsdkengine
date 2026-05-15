// Copyright (C) 2026 Parrot Drones SAS
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

/// Http generic client result
enum HttpGenericClientResult {
    /// Request completed successfully.
    case success

    /// Request failed.
    case failed

    /// Request was canceled by caller.
    case canceled
}

/// Generic client for HTTP requests.
///
/// This allows to execute "blind" requests with custom header and body, and retrieve the result.
class HttpGenericClient {

    /// Http session core
    let httpSession: HttpSessionCore

    /// constructor
    init(httpSession: HttpSessionCore) {
        self.httpSession = httpSession
    }

    /// deinit
    deinit {
        httpSession.close()
    }

    /// Executes an HTTP POST request.
    ///
    /// - Parameters:
    ///   - url: requested URL
    ///   - headerList: header list
    ///   - data: requested body
    ///   - trustAllCertificates: `true` to trust all certificates, `false` otherwise
    func execute(url: String, headers: [String], data: Data, trustAllCertificates: Bool = false,
                  completion: @escaping (Int?, HttpGenericClientResult, Data?) -> Void) -> CancelableCore? {

        guard let baseURL = URL(string: url) else {
            completion(-1, .failed, nil)
            return nil
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.httpBody = data

        /// add headers
        for header in headers {
            let parts = header.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        return httpSession.sendData(request: request, method: .post,
                                    trustAllCertificates: trustAllCertificates) { result, data in
            var returnCode: Int?
            var returnHttpError: HttpGenericClientResult
            switch result {
            case .canceled:
                returnHttpError = .canceled
            case .error(_):
                returnHttpError = .failed
            case .httpError(let error):
                returnCode = error
                returnHttpError = .failed
            case .success(_):
                returnHttpError = .success
                returnCode = 200
            }
            completion(returnCode, returnHttpError, data)
        }
    }
}
