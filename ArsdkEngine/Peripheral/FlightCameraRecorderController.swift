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

/// Controller for flight camera recorder peripheral.
class FlightCameraRecorderController: DeviceComponentController, FlightCameraRecorderBackend {

    /// Flight camera recorder component.
    private var flightCameraRecorder: FlightCameraRecorderCore!

    /// Component settings key
    private static let settingKey = "FlightCameraRecorderController"

     /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case activePipelinesKey = "activePipelines"
    }

    /// Stored settings
    enum Setting: Hashable {
        case activePipelines(Set<FlightCameraRecorderPipeline>)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .activePipelines: return .activePipelinesKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: Set<Setting> = [.activePipelines([])]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities.
    enum Capabilities {
        case pipelines(Set<FlightCameraRecorderPipeline>)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [.pipelines([])]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .pipelines: return .activePipelinesKey
            }
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this flight camera recorder interface
    private var presetStore: SettingsStore?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {

        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: FlightCameraRecorderController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: FlightCameraRecorderController.settingKey)
        }

        super.init(deviceController: deviceController)
        flightCameraRecorder = FlightCameraRecorderCore(store: deviceController.device.peripheralStore, backend: self)
        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            flightCameraRecorder.publish()
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let deviceStore = deviceStore, let presetStore = presetStore {
            Setting.allCases.forEach {
                switch $0 {
                case .activePipelines:
                    if let supportedPipelines: StorableArray<FlightCameraRecorderPipeline> = deviceStore.read(
                        key: $0.key),
                       let activePipelines: StorableArray<FlightCameraRecorderPipeline> = presetStore.read(
                        key: $0.key) {
                        flightCameraRecorder.update(supportedValues: Set(supportedPipelines.storableValue))
                            .update(activePipelines: Set(activePipelines.storableValue))
                            .notifyUpdated()
                    }
                }
            }
        }
    }

    /// Drone is connected.
    override func didConnect() {
        applyPresets()
        flightCameraRecorder.publish()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        flightCameraRecorder.cancelSettingsRollback()
        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            flightCameraRecorder.unpublish()
        }
        flightCameraRecorder.notifyUpdated()
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        flightCameraRecorder.unpublish()
        super.willForget()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: FlightCameraRecorderController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Apply presets
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .activePipelines(let activePipelines):
                if let preset: StorableArray<FlightCameraRecorderPipeline> = presetStore?.read(key: setting.key) {
                    if Set(preset.storableValue) != activePipelines {
                        sendConfigureCommand(Set(preset.storableValue))
                    }
                    flightCameraRecorder.update(activePipelines: Set(preset.storableValue)).notifyUpdated()
                } else {
                    flightCameraRecorder.update(activePipelines: activePipelines).notifyUpdated()
                }
            }
        }
    }

    /// Called when a command that notifies a setting change has been received.
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .activePipelines(let activePipelines):
            if connected {
                flightCameraRecorder.update(activePipelines: activePipelines).notifyUpdated()
            }
        }
    }

    /// Called when a command that notifies a capabilities change has been received.
    ///
    /// - Parameter capabilities: capabilities that changed
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .pipelines(let supportedPipelines):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(supportedPipelines))).commit()
            flightCameraRecorder.update(supportedValues: supportedPipelines)
        }
        flightCameraRecorder.notifyUpdated()
    }

    /// Sets active pipelines.
    ///
    /// - Parameter activePipelines: the new set of active pipelines
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(activePipelines: Set<FlightCameraRecorderPipeline>) -> Bool {
        presetStore?.write(key: SettingKey.activePipelinesKey, value: StorableArray(Array(activePipelines))).commit()
        if connected {
            sendConfigureCommand(activePipelines)
            return true
        } else {
            flightCameraRecorder.update(activePipelines: activePipelines).notifyUpdated()
            return false
        }
    }

    /// Configure command
    ///
    /// - Parameter activePipelines: requested active pipelines.
    func sendConfigureCommand(_ activePipelines: Set<FlightCameraRecorderPipeline>) {
        sendCommand(ArsdkFeatureFcr.configurePipelinesEncoder(pipelinesBitField: Bitfield.of(Array(activePipelines))))
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureFcrUid {
            ArsdkFeatureFcr.decode(command, callback: self)
        }
    }
}

/// Flight camera recorder decode callback implementation.
extension FlightCameraRecorderController: ArsdkFeatureFcrCallback {

    func onState(stateBitField: UInt64) {
        let activePipelines = FlightCameraRecorderPipeline.createSetFrom(bitField: stateBitField)
        settingDidChange(.activePipelines(activePipelines))
    }

    func onCapabilities(capabilitiesBitField: UInt64) {
        let supportedPipelines = FlightCameraRecorderPipeline.createSetFrom(bitField: capabilitiesBitField)
        capabilitiesDidChange(.pipelines(supportedPipelines))
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension FlightCameraRecorderPipeline: ArsdkMappableEnum {
    /// Create set of flight camera recorder pipeline from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all flight camera recorder pipeline type set in bitField
    static func createSetFrom(bitField: UInt64) -> Set<FlightCameraRecorderPipeline> {
        var result = Set<FlightCameraRecorderPipeline>()
        ArsdkFeatureFcrPipelineBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let state = FlightCameraRecorderPipeline(fromArsdk: arsdkValue) {
                result.insert(state)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<FlightCameraRecorderPipeline, ArsdkFeatureFcrPipeline>([
        .fcamTimelapse: .fcamTimelapse,
        .fcamFollowme: .fcamTracking,
        .fcamEmergency: .fcamEmergency,
        .fstcamLeftTimelapse: .fstcamLeftTimelapse,
        .fstcamLeftEmergency: .fstcamLeftEmergency,
        .fstcamLeftCalibration: .fstcamLeftCalibration,
        .fstcamLeftObstacleavoidance: .fstcamLeftObstacleavoidance,
        .fstcamRightTimelapse: .fstcamRightTimelapse,
        .fstcamRightEmergency: .fstcamRightEmergency,
        .fstcamRightCalibration: .fstcamRightCalibration,
        .fstcamRightObstacleavoidance: .fstcamRightObstacleavoidance,
        .vcamPrecisehovering: .vcamPrecisehovering,
        .vcamPrecisehome: .vcamPrecisehome,
        .fstcamRightPrecisehovering: .fstcamRightPrecisehovering,
        .fstcamLeftEvent: .fstcamLeftEvent,
        .fstcamRightEvent: .fstcamRightEvent,
        .fcamEvent: .fcamEvent
        ])
}

extension FlightCameraRecorderPipeline: StorableEnum {
    static let storableMapper = Mapper<FlightCameraRecorderPipeline, String>([
        .fcamTimelapse: "fcamTimelapse",
        .fcamFollowme: "fcamFollowme",
        .fcamEmergency: "fcamEmergency",
        .fstcamLeftTimelapse: "fstcamLeftTimelapse",
        .fstcamLeftEmergency: "fstcamLeftEmergency",
        .fstcamLeftCalibration: "fstcamLeftCalibration",
        .fstcamLeftObstacleavoidance: "fstcamLeftObstacleavoidance",
        .fstcamRightTimelapse: "fstcamRightTimelapse",
        .fstcamRightEmergency: "fstcamRightEmergency",
        .fstcamRightCalibration: "fstcamRightCalibration",
        .fstcamRightObstacleavoidance: "fstcamRightObstacleavoidance",
        .vcamPrecisehovering: "vcamPrecisehovering",
        .vcamPrecisehome: "vcamPrecisehome",
        .fstcamRightPrecisehovering: "fstcamRightPrecisehovering",
        .fstcamLeftEvent: "fstcamLeftEvent",
        .fstcamRightEvent: "fstcamRightEvent",
        .fcamEvent: "fcamEvent"
    ])
}
