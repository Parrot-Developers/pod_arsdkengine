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

/// Rest api for the flight camera records downloading through an http server.
class FlightCameraRecordRestApi {

    /// Drone server
    private let server: DeviceServer

    /// Base address to access the flight camera record api
    private let baseApi = "/api/v1/fcr/records"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which flight camera record should be accessed
    init(server: DeviceServer) {
        self.server = server
    }

    /// Get the list of all flight camera records on the drone
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - flightCameraRecordList: list of flight camera records available on the drone
    /// - Returns: the request
    func getFlightCameraRecordList(
        completion: @escaping (_ flightCameraRecordList: [FlightCameraRecord]?) -> Void) -> CancelableCore {
        return server.getData(api: "\(baseApi)") { result, data in
            switch result {
            case .success:
                // listing the flight camera records is successful
                if let data = data {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .formatted(.iso8601Base)
                    do {
                        let flightCameraRecords = try decoder.decode([FlightCameraRecord].self, from: data)
                        completion(flightCameraRecords)
                    } catch let error {
                        ULog.w(.flightCameraRecordTag,
                               "Failed to decode data \(String(data: data, encoding: .utf8) ?? ""): " +
                                error.localizedDescription)
                        completion(nil)
                    }
                }
            default:
                completion(nil)
            }
        }
    }

    /// Download a given flight camera record to a given directory
    ///
    /// - Parameters:
    ///   - flightCameraRecord: the flight camera record to download
    ///   - directory: the directory where to put the downloaded flight camera record into
    ///   - deviceUid: the device uid
    ///   - completion: the completion callback (called on the main thread)
    ///   - fileUrl: url of the locally downloaded file. `nil` if there were an error during download or during copy
    /// - Returns: the request
    func downloadFlightCameraRecord(
        _ flightCameraRecord: FlightCameraRecord, toDirectory directory: URL, deviceUid: String,
        completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore {

        let name = URL(string: flightCameraRecord.name)?.lastPathComponent ?? flightCameraRecord.name
        return server.downloadFile(
            api: flightCameraRecord.urlPath,
            destination: directory.appendingPathComponent(name),
            progress: { _ in },
            completion: { _, localFileUrl in
                completion(localFileUrl)
        })
    }

    /// Delete a given flight camera record on the device
    ///
    /// - Parameters:
    ///   - flightCameraRecord: the flight camera record to delete
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
    func deleteFlightCameraRecord(_ flightCameraRecord: FlightCameraRecord,
        completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.delete(api: "\(baseApi)/\(flightCameraRecord.name)") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// A flight camera record
    struct FlightCameraRecord: Decodable {
        enum CodingKeys: String, CodingKey {
            case name
            case date
            case size
            case urlPath = "url"
        }

        /// Flight camera record name
        let name: String
        /// Flight camera record date
        let date: Date
        /// Flight camera record size
        let size: Int
        /// Flight camera record url path (needs to be appended to an address and a port at least)
        let urlPath: String
    }
}
