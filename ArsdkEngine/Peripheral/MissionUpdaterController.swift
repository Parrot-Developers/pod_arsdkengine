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

/// Missions updater component controller
class MissionUpdaterController: DeviceComponentController {

    /// Mission updater component.
    private(set) var missionUpdater: MissionUpdaterCore!

    /// Mission updater rest api
    private var missionUpdaterRestApi: MissionUpdaterRestApi?

    /// Mission list whose assets are not yet downloaded
    private var pendingMissions: [String: MissionCore] = [:]

    /// Queue of mission assets to be downloaded.
    private var downloadAssetQueue: [String] = []

    /// Whether or not the current overall task has been canceled
    private var isCanceled = false

    /// Mission asset storage utility.
    private var missionAssetStorage: MissionAssetStorageCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        missionAssetStorage = deviceController.engine.utilities.getUtility(Utilities.missionAssetStorage)
        missionUpdater = MissionUpdaterCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        if let droneServer = deviceController.deviceServer {
            missionUpdaterRestApi = MissionUpdaterRestApi(server: droneServer)
        }
        missionUpdater.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        missionUpdaterRestApi = nil
        missionUpdater.update(state: nil)
            .update(progress: nil)
            .update(filePath: nil)
            .update(missions: [:])
            .unpublish()
    }
}

/// Mission updater backend implementation
extension MissionUpdaterController: MissionUpdaterBackend {
    func upload(filePath: URL, overwrite: Bool, postpone: Bool, makeDefault: Bool) -> CancelableCore? {
        missionUpdater.update(state: .uploading)
            .update(progress: 0)
            .update(filePath: filePath.absoluteString)
            .notifyUpdated()

        return missionUpdaterRestApi?.upload(
            missionFile: filePath, overwrite: overwrite, postpone: postpone, makeDefault: makeDefault,
            progress: { currentProgress in
                self.missionUpdater.update(progress: currentProgress).notifyUpdated()
            },
            completion: { error in
                self.missionUpdater.update(progress: nil)
                if let error = error {
                    self.missionUpdater.update(state: .failed(error: error)).notifyUpdated()

                } else {
                    self.missionUpdater.update(state: .success)
                        .update(filePath: nil).notifyUpdated()
                }
            })
    }

    func delete(uid: String, success: @escaping (Bool) -> Void) {
        missionUpdaterRestApi?.deleteMission(uid: uid) { result in
            success(result)
        }
    }

    public func browse() {
        _ = missionUpdaterRestApi?.getMissionList { missionList in
            self.missionUpdater.update(missions: missionList).notifyUpdated()
            self.pendingMissions = missionList
            self.cleanUpMissionAssetStorage()
            self.browseNextMissionAssets()
        }
    }

    /// Requests the list of assets of the next mission from the drone.
    private func browseNextMissionAssets() {
        if let mission = pendingMissions.first?.value {
            _ = self.missionUpdaterRestApi?.browseAssets(mission: mission) { missionDetail in
                if let missionDetail = missionDetail, let assets = missionDetail.assets, !assets.isEmpty {
                    self.downloadAssetQueue = assets
                    self.cleanAssets(in: self.missionAssetStorage.workDir
                        .appendingPathComponent(mission.uid).absoluteString)
                    self.downloadNextAsset(mission: missionDetail)
                    self.pendingMissions.removeValue(forKey: missionDetail.uid)
                } else {
                    self.pendingMissions.removeValue(forKey: mission.uid)
                    self.browseNextMissionAssets()
                }
            }
        } else {
            missionUpdater?.update(isDownloadingAsset: false)
                .update(assetDownloadStatus: .success)
                .notifyUpdated()
            missionAssetStorage.notifyStoreChanged()
        }
    }

    /// Clean up asset folders of inexistent missions
    private func cleanUpMissionAssetStorage() {
        let fileManager = FileManager.default
        do {
            let missionFolders = try fileManager.contentsOfDirectory(atPath: missionAssetStorage.workDir.path)
            for folder in missionFolders {
                let folderName = URL(fileURLWithPath: folder).lastPathComponent
                if pendingMissions.keys.contains(folderName) == false {
                    // Remove the entire mission folder if it is not pending
                    do {
                        try fileManager.removeItem(atPath: folder)
                    } catch {
                        ULog.e(.missionsTag, "Error deleting folder: \(folder): \(error)")
                    }
                }
            }
        } catch {
            ULog.e(.missionsTag, "Error reading mission directory: \(missionAssetStorage.workDir.path) - \(error)")
        }
    }

    /// Downloads the next mission asset from the drone.
    ///
    /// - Parameter mission: the corresponding mission
    private func downloadNextAsset(mission: MissionCore) {
        if let asset = downloadAssetQueue.first {
            let missionUidDir = missionAssetStorage.workDir.appendingPathComponent(mission.uid)

            _ = missionUpdaterRestApi?.downloadMissionFile(asset, toDirectory: missionUidDir,
                                                           progress: { _ in },
                                                           completion: { result, _ in
                if case .canceled = result {
                    self.missionUpdater?.update(isDownloadingAsset: false)
                        .update(assetDownloadStatus: .interrupted)
                        .notifyUpdated()
                }
                self.downloadAssetQueue.removeFirst()
                self.downloadNextAsset(mission: mission)
            })

            missionUpdater?.update(isDownloadingAsset: true)
                .update(assetDownloadStatus: .none)
                .notifyUpdated()
        } else {
            self.browseNextMissionAssets()
        }
    }

    /// Remove local saved assets not anymore existing in the drone.
    private func cleanAssets(in folderPath: String) {
        let fileManager = FileManager.default
        do {
            let assets = try fileManager.contentsOfDirectory(atPath: folderPath)
            for asset in assets {
                let fileName = URL(fileURLWithPath: asset).lastPathComponent
                if !downloadAssetQueue.contains(where: { URL(fileURLWithPath: $0).lastPathComponent == fileName }) {
                    do {
                        try fileManager.removeItem(atPath: asset)
                    } catch {
                        ULog.e(.missionsTag, "Error deleting asset \(asset): \(error)")
                    }
                }
            }
        } catch {
            ULog.e(.missionsTag, "Failed to clean assets in folder \(folderPath): \(error)")
        }
    }

    public func complete() {
        _ = sendCommand(ArsdkFeatureCommonCommon.rebootEncoder())
    }
}
