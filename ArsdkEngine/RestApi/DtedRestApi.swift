// Copyright (C) 2023 Parrot Drones SAS
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

/// Rest api to get/delete dtedd file through an http server.
class DtedRestApi {

    /// Drone server
    private let server: DeviceServer

    /// Base address to access the dted api
    private let baseApi: String

    /// Constructor
    ///
    /// - Parameters:
    ///   - server: the drone server from which dted files should be accessed
    ///   - deviceModel: the device model
    init(server: DeviceServer, deviceModel: DeviceModel) {
        self.server = server

        switch deviceModel {
        case .drone(let droneModel):

            switch droneModel {
            case .anafi4k, .anafiThermal, .anafi2, .anafiUa, .anafiUsa:
                baseApi = "api/v1/upload-terrain"

            default:
                baseApi = "api/v1/terrain"
            }

        case .rc:
            baseApi = ""
        }
    }

    /// Get the list of all dted files on the drone
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - fileList: list of dted files on the drone
    /// - Returns: the request
    func getFileList(
        completion: @escaping (_ fileList: [DtedFileCore]?) -> Void) -> CancelableCore {
            let api = "\(baseApi)/terrains"

            return server.getData(api: api) { result, data in
                switch result {
                case .success:
                    // listing files is successful
                    guard let data = data else { return }
                    let decoder = JSONDecoder()
                    // need to override the way date are parsed because default format is iso8601 extended
                    decoder.dateDecodingStrategy = .formatted(.iso8601Base)
                    do {
                        // decode the dted file list, failed file will be ignored
                        let throwables = try decoder.decode([Throwable<File>].self, from: data)
                        let fileList = throwables.compactMap { try? $0.result.get() }
                        // transform the json object dted file list into a `DtedFileCore` list
                        let files = fileList.map { DtedFileCore.from(httpFile: $0) }.compactMap { $0 }
                        completion(files)
                    } catch let error {
                        ULog.w(.dtedTag, "Failed to decode data \(String(data: data, encoding: .utf8) ?? ""): " +
                               error.localizedDescription)
                        completion(nil)
                    }
                default:
                    completion(nil)
                }
            }
        }

    /// Get the dted file on the drone from location.
    ///
    /// - Parameters:
    ///   - latitude: the location latitude
    ///   - longitude: the location longitude
    ///   - completion: closure called when the request is terminated
    /// - Returns: a request that can be canceled
    func getFile(latitude: Double, longitude: Double,
        completion: @escaping (_ file: DtedFileCore?) -> Void) -> CancelableCore {
            let api = "\(baseApi)/terrain"
            let query = ["latitude": "\(latitude)", "longitude": "\(longitude)"]
            return server.getData(api: api, query: query) { result, data in
                switch result {
                case .success:
                    // listing files is successful
                    guard let data = data else { return }
                    let decoder = JSONDecoder()
                    // need to override the way date are parsed because default format is iso8601 extended
                    decoder.dateDecodingStrategy = .formatted(.iso8601Base)
                    do {
                        // decode the dted file, failed file will be ignored
                        let throwable = try decoder.decode(Throwable<File>.self, from: data)
                        if let file = try? throwable.result.get() {
                            completion(DtedFileCore.from(httpFile: file))
                        } else {
                            completion(nil)
                        }
                    } catch let error {
                        ULog.w(.dtedTag, "Failed to decode data \(String(data: data, encoding: .utf8) ?? ""): " +
                               error.localizedDescription)
                        completion(nil)
                    }
                default:
                    completion(nil)
                }
            }
        }

    /// Uploads a dted file.
    ///
    /// - Parameters:
    ///   - fileUrl: the file to upload
    ///   - progress: progress callback
    ///   - progressValue: the progress value, from 0 to 100
    ///   - completion: completion callback
    /// - Returns: a request that can be canceled
    func upload(
        fileURL: URL, progress: @escaping (_ progressValue: Int) -> Void,
        completion: @escaping (_ success: Bool) -> Void) -> CancelableCore? {
            return server.putFile(api: "\(baseApi)/terrain/\(fileURL.lastPathComponent)",
                                  fileUrl: fileURL,
                                  progress: progress,
                                  completion: { result, _ in
                switch result {
                case .success:
                    completion(true)
                default:
                    completion(false)
                }
            })
        }

    // Delete dted file
    ///
    /// - Parameters:
    ///   - fileName: file name to delete
    ///   - completion: completion callback
    /// - Returns: delete request, or `nil` if the request can't be sent
    func deleteFile(_ fileName: String, completion: @escaping (_ success: Bool) -> Void) -> CancelableCore {
        return server.delete(api: "\(baseApi)/terrain/\(fileName)") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// An object representing the dted file as the REST api describes it.
    /// This object has all the field of the json object given by the REST api.
    internal struct File: Decodable {
        enum CodingKeys: String, CodingKey {
            case filename
            case date
            case md5
            case valid
            case latitudeSw = "latitude SW"
            case longitudeSw = "longitude SW"
            case latitudeSpacing = "latitude spacing"
            case longitudeSpacing = "longitude spacing"
            case elevation = "elevation at req"
        }

        let filename: String
        let date: Date
        let md5: String
        let valid: Bool
        let latitudeSw: Int
        let longitudeSw: Int
        let latitudeSpacing: Double
        let longitudeSpacing: Double
        let elevation: Double?

        /// Custom initializer which allows to safely decode the resource array, ignoring the ones that could not be
        /// decoded and keeping the others.
        ///
        /// - Parameter decoder: the decoder to read data from
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            filename = try values.decode(String.self, forKey: .filename)
            date = try values.decode(Date.self, forKey: .date)
            md5 = try values.decode(String.self, forKey: .md5)
            valid = try values.decode(Bool.self, forKey: .valid)
            latitudeSw = try values.decode(Int.self, forKey: .latitudeSw)
            longitudeSw = try values.decode(Int.self, forKey: .longitudeSw)
            latitudeSpacing = try values.decode(Double.self, forKey: .latitudeSpacing)
            longitudeSpacing = try values.decode(Double.self, forKey: .longitudeSpacing)
            elevation = try values.decodeIfPresent(Double.self, forKey: .elevation)
        }
    }

    /// Origin as described by the REST api.
    internal struct Origin: Decodable {
        enum CodingKeys: String, CodingKey {
            case latitude
            case longitude
        }

        let latitude: Double
        let longitude: Double
    }

    /// GridResolution as described by the REST api.
    internal struct GridResolution: Decodable {
        enum CodingKeys: String, CodingKey {
            case latitudeSpacing
            case longitudeSpacing
        }

        let latitudeSpacing: Double
        let longitudeSpacing: Double
    }
}

/// Extension of DtedFileCore that adds creation from http dted file objects
internal extension DtedFileCore {
    /// Creates a dred file from an http dted file
    ///
    /// - Parameter httpFile: the http dted file
    /// - Returns: a dted file if the http dted file is compatible with the DtedFile declaration
    static func from(httpFile: DtedRestApi.File) -> DtedFileCore? {
        let origin = CLLocationCoordinate2D(latitude: Double(httpFile.latitudeSw),
                                            longitude: Double(httpFile.longitudeSw))
        let gridResolution = GridResolution(
            latitudeSpacing: httpFile.latitudeSpacing,
            longitudeSpacing: httpFile.longitudeSpacing)
        return DtedFileCore(name: httpFile.filename,
                            uploadDate: httpFile.date, origin: origin,
                            gridResolution: gridResolution, checksum: nil, elevation: httpFile.elevation)

    }
}
