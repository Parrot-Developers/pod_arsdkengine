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
import CoreLocation

/// REST API to list available modules/services via HTTP.
class ModulesRestApi {

    /// Drone server
    private let server: DeviceServer

    /// Base address to access the web modules api
    private let baseApi = "/api/v1/web"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which modules should be accessed
    init(server: DeviceServer) {
        self.server = server
    }

    /// Lists available modules/services on the device.
    ///
    /// - Parameter completion:the completion callback (called on the main thread)
    /// - Returns: the request
    @discardableResult
    func listModules(completion: @escaping (_ modules: [HttpService]?) -> Void) -> CancelableCore {
        return server.getData(api: "\(baseApi)/modules") { result, data in
            switch result {
            case .success:
                guard let data = data else {
                    completion(nil)
                    return
                }
                let decoder = JSONDecoder()
                do {
                    let modules = try decoder.decode([HttpService].self, from: data)
                    completion(modules)
                } catch {
                    ULog.e(.tag, "Failed to decode modules: \(String(data: data, encoding: .utf8) ?? "") - \(error)")
                    completion(nil)
                }
            default:
                completion(nil)
            }
        }
    }
}

/// Represents the HttpService.
public enum HttpService: String, CaseIterable {
    case web
    case update
    case report
    case info
    case credential
    case uploadTerrain = "upload-terrain"
    case terrain
    case diagnostics
    case fdr
    case fcr
    case map
    case media
    case mission
    case sdk
    case secureElement = "secure-element"
    case system
    case upload
    case uploadOlCerts = "upload-ol-certs"
    case unknown
}

extension HttpService: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let matched = HttpService.allCases.first(where: { $0.rawValue == raw.lowercased() }) {
            self = matched
        } else {
            self = .unknown
        }
    }
}

extension HttpService: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
