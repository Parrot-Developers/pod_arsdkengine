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

    /// Constructor
    ///
    /// - Parameter: deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        missionUpdater = MissionUpdaterCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        if let droneServer = deviceController.droneServer {
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
    func upload(filePath: URL, overwrite: Bool, postpone: Bool) -> CancelableCore? {
        missionUpdater.update(state: .uploading)
            .update(progress: 0)
            .update(filePath: filePath.absoluteString)
            .notifyUpdated()

        return missionUpdaterRestApi?.upload(missionFile: filePath, allowOverwrite: overwrite, postpone: postpone,
            progress: {currentProgress in
                self.missionUpdater.update(progress: currentProgress).notifyUpdated()
        }, completion: { error in
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
        }

    }

    public func complete() {
        sendCommand(ArsdkFeatureCommonCommon.rebootEncoder())
    }
}
