// Copyright (C) 2019 Parrot Drones SAS
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

// Rest api to get/delete/upload mision through an http server.
class MissionUpdaterRestApi {

    /// Drone server
    private let server: DroneServer

    /// Base address to access the mission api
    private let baseApi = "/api/v1/mission/missions"

    /// Constructor
    ///
    /// - Parameter server: the drone server from which missions should be accessed
    init(server: DroneServer) {
        self.server = server
    }

    /// Get the list of all missions on the drone
    ///
    /// - Parameters:
    ///   - completion: the completion callback (called on the main thread)
    ///   - missionList: list of missions on the drone
    /// - Returns: the request
    func getMissionList(
        completion: @escaping (_ missionList: [String: MissionCore]) -> Void) -> CancelableCore {
        return server.getData(api: baseApi) { result, data in
            switch result {
            case .success:
                // listing missions is successful
                if let data = data {
                    let decoder = JSONDecoder()
                    // need to override the way date are parsed because default format is iso8601 extended
                    decoder.dateDecodingStrategy = .formatted(.iso8601Base)
                    do {

                        let missionList = try decoder.decode([MissionDecodable].self, from: data)
                        // transform the json object missions list into a `MissionCore` list
                        let missions = missionList.map { MissionCore.from(httpMission: $0) }.compactMap { $0 }
                        var finalMissions: [String: MissionCore] = [:]
                        for mission in missions {
                            finalMissions[mission.uid] = mission
                        }
                        completion(finalMissions)
                    } catch let error {
                        ULog.w(.missionsTag, "Failed to decode data \(String(data: data, encoding: .utf8) ?? ""): " +
                            error.localizedDescription)
                        completion([:])
                    }
                }
            default:
                completion([:])
            }
        }
    }

    /// Delete a given mission on the drone
    ///
    /// - Parameters:
    ///   - mission: the mission to delete
    ///   - completion: the completion callback (called on the main thread)
    ///   - success: whether the delete task was successful or not
    /// - Returns: the request
    func deleteMission(uid: String, completion: @escaping (_ success: Bool) -> Void) {
        _ = server.delete(api: "\(baseApi)/\(uid)") { result in
            switch result {
            case .success:
                completion(true)
            default:
                completion(false)
            }
        }
    }

    /// Upload a mission
    ///
    /// - Parameters:
    ///   - missionFile: url of the mission file
    ///   - allowOverwrite: allow overwrite of the mission
    ///   - postpone: postpone the installation until next reboot
    /// - Returns:  the update request, nil if it could not start the update.
    func upload(missionFile: URL, allowOverwrite: Bool, postpone: Bool, progress: @escaping (_ progress: Int) -> Void,
        completion: @escaping (_ error: MissionUpdaterError?) -> Void) -> CancelableCore? {

        return server.putFile(api: "\(baseApi)/",
                              query: ["allow_overwrite": (allowOverwrite ? "yes" : "no"),
                                      "is_delayed": (postpone ? "yes" : "no")],
                              fileUrl: missionFile,
                              progress: { progressValue in
            progress(progressValue)
        }, completion: { result, _ in
            switch result {
            case .success:
                completion(nil)
            case .canceled:
                completion(.canceled)
            case .error(let error):
                switch (error  as NSError).urlError {
                case .canceled:
                    completion(.canceled)
                case .connectionError:
                    completion(.connectionError)
                case .otherError:
                    // by default, blame the error on the mission file.
                    completion(.badMissionFile)
                }
            case .httpError(let errorCode):
                switch errorCode {
                case 403: // mission already exist on drone but overwrite parameter was false
                    completion(.missionAlreadyExists)
                case 405: // Api called to install mission is incorrect
                    completion(.incorrectMethod)
                case 415: // installation of mission failed
                    completion(.installationFailed)
                case 429: // another upload is already in progress
                    completion(.busy)
                case 507: // no space left to install mission
                    completion(.noSpaceLeft)
                case 404, // not found
                    500: // internal server error
                    completion(.serverError)
                case 550: // mission signature is invalid
                    completion(.invalidSignature)
                case 551: // version of mission doesn't match with drone version
                    completion(.versionMismatch)
                case 552: // wrong drone for this mission
                    completion(.modelMismatch)
                case 553: // Something is wrong with the installation file
                    completion(.badInfoFile)
                case 554: // wrong drone for this mission
                    completion(.corruptedFile)
                default:
                    completion(.serverError)
                }
            }
        })
    }

    /// An object representing the mission as the REST api describes it.
    /// This object has all the field of the json object given by the REST api.
    fileprivate struct MissionDecodable: Decodable {
        enum CodingKeys: String, CodingKey {
            case uid = "uid"
            case descriptor = "desc"
            case name = "name"
            case minTargetVersion = "target_min_version"
            case maxTargetVersion = "target_max_version"
            case version = "version"
            case targetModelId = "target_model_id"
        }

        /// Mission id
        let uid: String

        /// Descriptor.
        let descriptor: String

        /// Name of the mission
        let name: String

        /// Minimum version of target supported.
        let minTargetVersion: String

        /// Maximum version of target supported.
        let maxTargetVersion: String

        /// Version of the mission.
        let version: String

        /// Model id of the supported target.
        let targetModelId: UInt
    }
}

fileprivate extension MissionCore {
    /// Creates a mission from an http mission
    ///
    /// - Parameter httpMission: the http mission
    /// - Returns: a mission if the http mission is compatible with the MissionDecodable declaration
    static func from(httpMission: MissionUpdaterRestApi.MissionDecodable) -> MissionCore? {
        let deviceModel = DeviceModel.from(internalId: Int(httpMission.targetModelId))
        var targetModel: Drone.Model?
        switch deviceModel {
        case .drone(let model):
            targetModel = model
        default:
            break
        }
        return MissionCore(uid: httpMission.uid, description: httpMission.descriptor, name: httpMission.name,
                           version: httpMission.version, recipientId: nil,
                           targetModelId: targetModel,
                           minTargetVersion: FirmwareVersion.parse(versionStr: httpMission.minTargetVersion),
                           maxTargetVersion: FirmwareVersion.parse(versionStr: httpMission.maxTargetVersion))
    }
}
