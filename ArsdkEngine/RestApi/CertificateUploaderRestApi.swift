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

/// REST API for certificate upload to an HTTP server.
class CertificateUploaderRestApi {

    /// Result of an upload request.
    enum Result: CustomStringConvertible {
        /// The request succeeded
        case success
        /// The request failed
        case error
        /// The request has been canceled
        case canceled

        /// Debug description.
        public var description: String {
            switch self {
            case .success:  return "success"
            case .error:    return "error"
            case .canceled: return "canceled"
            }
        }
    }

    /// Drone server.
    private let server: DeviceServer

    /// Base address to access the license certificate API.
    private let baseApi = "/api/v1/upload-ol-certs"

    /// Constructor
    ///
    /// - Parameter server: the drone server that the update should use
    init(server: DeviceServer) {
        self.server = server
    }

    /// Uploads a security edition certificate to the drone.
    ///
    /// - Parameters:
    ///   - filepath: certificate's filepath to upload
    ///   - completion: the completion callback (called on the main thread)
    ///   - result: the completion result
    /// - Returns: the request
    func uploadCredential(filepath: String, completion: @escaping (_ result: Result) -> Void) -> CancelableCore {
        return server.putFile(
            api: "/api/v1/credential/certificate",
            fileUrl: URL(fileURLWithPath: filepath),
            progress: { _ in },
            completion: { result, _ in
                switch result {
                case .success:
                    completion(.success)
                case .error, .httpError:
                    completion(.error)
                case .canceled:
                    completion(.canceled)
                }
            })
    }

    /// Uploads a license certificate to the drone.
    ///
    /// - Parameters:
    ///   - filepath: certificate's filepath to upload
    ///   - completion: the completion callback (called on the main thread)
    ///   - result: the completion result
    /// - Returns: the request
    func uploadLicense(filepath: String, completion: @escaping (_ result: Result) -> Void) -> CancelableCore {
        return server.putFile(
            api: "\(baseApi)/license",
            query: ["persist_level": "user"],
            fileUrl: URL(fileURLWithPath: filepath),
            progress: { _ in },
            completion: { result, _ in
                switch result {
                case .success:
                    completion(.success)
                case .error, .httpError:
                    completion(.error)
                case .canceled:
                    completion(.canceled)
                }
            })
    }

    /// Fetches the signature of the current license certificate installed on the drone.
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - signature: the retrieved signature
    /// - Returns: the request
    func fetchSignature(completion: @escaping (_ signature: String?) -> Void) -> CancelableCore {
        return server.getData(
            api: "\(baseApi)/license",
            query: ["persist_level": "user", "format": "json"],
            completion: { result, data in
                switch result {
                case .success:
                    if let data = data {
                        let decoder = JSONDecoder()
                        do {
                            let certificate = try decoder.decode(CertificateDecodable.self, from: data)
                            completion(certificate.signature)
                        } catch let error {
                            ULog.e(.certificateTag, "Failed to decode data "
                                   + "\(String(data: data, encoding: .utf8) ?? ""): \(error.localizedDescription)")
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                default:
                    completion(nil)
                }
            })
    }

    /// Fetches the information of the current license certificate installed on the drone.
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - info: the retrieved information
    /// - Returns: the request
    func fetchInfo(completion: @escaping (_ info: CertificateInfo?) -> Void) -> CancelableCore {
        return server.getData(
            api: "\(baseApi)/info",
            completion: { result, data in
                switch result {
                case .success:
                    if let data = data {
                        let decoder = JSONDecoder()
                        do {
                            let info = try decoder.decode(InfoDecodable.self, from: data)
                            completion(CertificateInfo(debugFeatures: info.features.debug,
                                                       premiumFeatures: info.features.premium))
                        } catch let error {
                            ULog.e(.certificateTag, "Failed to decode data "
                                   + "\(String(data: data, encoding: .utf8) ?? ""): \(error.localizedDescription)")
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                default:
                    completion(nil)
                }
            })
    }

    /// An object representing the certificate as the REST API describes it.
    private struct CertificateDecodable: Decodable {
        enum CodingKeys: String, CodingKey {
            case signature
        }

        /// Signature
        let signature: String
    }

    /// An object representing the certificate information as the REST API describes it.
    private struct InfoDecodable: Decodable {
        enum CodingKeys: String, CodingKey {
            case features
        }

        /// Features
        let features: FeaturesDecodable
    }

    /// Certificate features as described by the REST API.
    private struct FeaturesDecodable: Decodable {
        enum CodingKeys: String, CodingKey {
            case debug
            case premium
        }

        /// Debug features
        let debug: [String]

        /// Premium features
        let premium: [String]
    }
}
