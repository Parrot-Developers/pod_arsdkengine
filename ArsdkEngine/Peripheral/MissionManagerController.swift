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

/// Base controller for mission manager peripheral
class MissionManagerController: DeviceComponentController, MissionManagerBackend {

    /// Missions Manager
    private var missionManager: MissionManagerCore!

    private var missions: [String: MissionCore] = [:]

    /// Device representation in the persistent store
    let deviceStore: SettingsStore

    /// Component settings key
    private static let settingKey = "MissionManagerController"

    /// All settings that can be stored
   enum SettingKey: String, StoreKey {
       case missionsKey = "missions"
   }

    /// Stored capabilities.
    enum Capabilities {
        case missions([String: MissionCore])

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [.missions([:])]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .missions: return .missionsKey
            }
        }
    }

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        deviceStore = deviceController.deviceStore.getSettingsStore(key: MissionManagerController.settingKey)
        super.init(deviceController: deviceController)

        missionManager = MissionManagerCore(store: deviceController.device.peripheralStore, backend: self)

        // load settings
        if !deviceStore.new {
            loadPersistedData()
            if missions.count > 0 {
                missionManager.publish()
            }
        }
    }

    /// Load saved settings
    private func loadPersistedData() {
        // load missions
        if let missionsData: StorableArray<MissionStorable> = deviceStore.read(key: SettingKey.missionsKey) {
            for mission in missionsData.storableValue {
                missions[mission.uid] = mission.mission
            }
            missionManager.update(missions: missions).notifyUpdated()
        }
    }

    /// Load the mission.
    ///
    /// - Parameter uid: mission unique identifier
    func load(uid: String) {
        sendCommand(ArsdkFeatureMission.loadEncoder(uid: uid))
    }

    /// Unload the mission.
    ///
    /// - Parameter uid: mission unique identifier
    func unload(uid: String) {
        sendCommand(ArsdkFeatureMission.unloadEncoder(uid: uid))
    }

    /// Activate the mission.
    ///
    /// - Parameter uid: mission unique identifier
    func activate(uid: String) {
        sendCommand(ArsdkFeatureMission.activateEncoder(uid: uid))
    }

    /// Send message
    ///
    /// - Parameter message: mission message
    func sendMessage(message: MissionMessage) {
        if let mission = missions[message.missionUid], let recipientId = mission.recipientId {
            sendCommand(ArsdkFeatureMission.customCmdEncoder(recipientId: recipientId,
                serviceId: message.serviceUid,
                msgNum: message.messageUid, payload: message.payload))
        }
    }

    /// Drone did connect.
    override func didConnect() {
        if missions.count > 0 {
            sendCommand(ArsdkFeatureMission.customMsgEnableEncoder())
            missionManager.publish()
        }
        super.didConnect()
    }

    /// Drone did disconnect.
    override func didDisconnect() {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            missionManager.unpublish()
        } else {
            for mission in missions {
                let mission = mission.value
                missionManager.update(uid: mission.uid, state: .unavailable, unavailabilityReason: .none)
                missionManager.reset(updatingMission: mission.uid)
            }
            missionManager.notifyUpdated()
        }
        super.didDisconnect()
    }

    /// Drone is about to be forgotten
    override func willForget() {
        missionManager.unpublish()
        super.willForget()
    }

    /// Called when a command that notifies a capabilities change has been received.
    ///
    /// - Parameter capabilities: capabilities that changed
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .missions(let missionsSupported):

            var missionArray = Set<MissionStorable>()
            for mission in missionsSupported {
                missionArray.insert(MissionStorable(mission: mission.value))
            }
            deviceStore.write(key: capabilities.key, value: StorableArray(Array(missionArray))).commit()
            missionManager.update(missions: missionsSupported)
        }
        missionManager.notifyUpdated()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureMissionUid {
            ArsdkFeatureMission.decode(command, callback: self)
        }
    }
}

/// Mission manager decode callback implementation
extension MissionManagerController: ArsdkFeatureMissionCallback {

    func onCapabilities(uid: String!, name: String!, desc: String!, version: String!, recipientId: UInt,
        targetModelId: UInt, targetMinVersion: String!, targetMaxVersion: String!, listFlagsBitField: UInt) {
        let targetModel = DeviceModel.from(internalId: Int(targetModelId))
        switch targetModel {
        case .drone(let model):
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                missions.removeAll()
            } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                missions[uid] = nil
            }
            let mission = MissionCore(uid: uid, description: desc, name: name, version: version,
                recipientId: recipientId, targetModelId: model,
                minTargetVersion: FirmwareVersion.parse(versionStr: targetMinVersion),
                maxTargetVersion: FirmwareVersion.parse(versionStr: targetMaxVersion))

                missions[uid] = mission
                if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                    capabilitiesDidChange(.missions(missions))
                    missionManager.update(missions: missions).notifyUpdated()
                }
        default:
            break
        }
    }

    func onState(uid: String!, state: ArsdkFeatureMissionState,
        unavailabilityReason: ArsdkFeatureMissionUnavailabilityReason) {
        guard missions[uid] != nil else {
            return
        }

        var stateMission: MissionState = .unavailable
        switch state {
        case .active:
            stateMission = .active
        case .idle:
            stateMission = .idle
        case .unavailable:
            stateMission = .unavailable
        case .unloaded:
            stateMission = .unloaded
        case .sdkCoreUnknown:
            break

        @unknown default:
            break
        }

        var reason: MissionUnavailabilityReason = .broken
        switch unavailabilityReason {
        case .broken:
            reason = .broken
        case .loadFailed:
            reason = .loadFailed
        case .none:
            reason = .none
        case .sdkCoreUnknown:
            break
        @unknown default:
            break
        }
        missionManager.update(uid: uid, state: stateMission, unavailabilityReason: reason).notifyUpdated()
    }

    func onCustomEvt(recipientId: UInt, serviceId: UInt, msgNum: UInt, payload: Data!) {
        for mission in missions where mission.value.recipientId == recipientId {
            missionManager.update(message: MissionMessageCore(
                missionUid: mission.value.uid, serviceUid: serviceId,
                messageUid: msgNum, payload: payload)).notifyUpdated()
            missionManager.update(message: nil).notifyUpdated()
            break
        }
    }

    func onSuggestedActivation(uid: String!) {
        missionManager.update(suggestedActivation: uid).notifyUpdated()
        missionManager.update(suggestedActivation: nil).notifyUpdated()
    }
}

/// Mission storable
private struct MissionStorable: StorableType, Hashable {

    var uid = ""
    var description = ""
    var name = ""
    var version = ""
    var targetModelId: Int = 0
    var minTargetVersion = "0.0.0"
    var maxTargetVersion = "0.0.0"

    /// Store keys
    private enum Key {
        static let uid = "uid"
        static let description = "description"
        static let name = "name"
        static let version = "version"
        static let targetModelId = "targetModelId"
        static let minTargetVersion = "minTargetVersion"
        static let maxTargetVersion = "maxTargetVersion"
    }

    /// Constructor from store data
    ///
    /// - Parameter content: store data
    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
           let uid = String(content[Key.uid]),
           let description = String(content[Key.description]),
           let name = String(content[Key.name]),
           let version = String(content[Key.version]),
           let targetModelId = Int(content[Key.targetModelId]),
           let minTargetVersion = String(content[Key.minTargetVersion]),
           let maxTargetVersion = String(content[Key.maxTargetVersion]) {
            self.uid = uid.storableValue
            self.description = description.storableValue
            self.name = name.storableValue
            self.version = version.storableValue
            self.targetModelId = targetModelId.storableValue
            self.minTargetVersion = minTargetVersion.storableValue
            self.maxTargetVersion = maxTargetVersion.storableValue
            self.mission = MissionCore(uid: uid, description: description, name: name, version: version,
                                       recipientId: nil, targetModelId: Drone.Model(rawValue: targetModelId),
                                       minTargetVersion: FirmwareVersion.parse(versionStr: minTargetVersion),
                                       maxTargetVersion: FirmwareVersion.parse(versionStr: maxTargetVersion))
        } else {
            return nil
        }
    }

    /// Mission, used to get capabilities
    public var mission: MissionCore?

    /// Constructor
    ///
    /// - Parameter mission: mission settings
    init(mission: MissionCore) {
        self.mission = mission
        self.uid = mission.uid
        self.description = mission.description
        self.name = mission.name
        self.version = mission.version
        self.targetModelId = mission.targetModelId?.rawValue ?? 0
        self.minTargetVersion = mission.minTargetVersion?.description ?? "0.0.0"
        self.maxTargetVersion = mission.maxTargetVersion?.description ?? "0.0.0"
    }

    /// Convert data to storable
    ///
    /// - Returns: Storable containing data
    func asStorable() -> StorableProtocol {
        return StorableDict<String, AnyStorable>([
            Key.uid: AnyStorable(uid),
            Key.description: AnyStorable(description),
            Key.name: AnyStorable(name),
            Key.version: AnyStorable(version),
            Key.targetModelId: AnyStorable(targetModelId),
            Key.minTargetVersion: AnyStorable(minTargetVersion),
            Key.maxTargetVersion: AnyStorable(maxTargetVersion)
        ])
    }

    static func == (lhs: MissionStorable, rhs: MissionStorable) -> Bool {
        return lhs.uid == rhs.uid && lhs.description == rhs.description && lhs.name == rhs.name
    }
}
