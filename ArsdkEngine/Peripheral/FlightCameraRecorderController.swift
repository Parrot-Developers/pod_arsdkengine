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
        case pipelinesConfigurationKey = "pipelinesConfiguration"
    }

    /// Preset store for this flight camera recorder interface
    private var presetStore: SettingsStore?

    /// Current pipelines configuration identifier on the drone.
    private var currentId = UInt64(0)

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {

        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            presetStore = nil
        } else {
            presetStore = deviceController.presetStore.getSettingsStore(key: FlightCameraRecorderController.settingKey)
        }

        super.init(deviceController: deviceController)
        flightCameraRecorder = FlightCameraRecorderCore(store: deviceController.device.peripheralStore, backend: self)
        // load settings
        if let presetStore = presetStore, !presetStore.new {
            loadPresets()
            flightCameraRecorder.publish()
        }
    }

    /// Load saved pipelines configuration identifier.
    private func loadPresets() {
        if let presetStore = presetStore {
            if let presetId: UInt64 = presetStore.read(key: SettingKey.pipelinesConfigurationKey) {
                flightCameraRecorder.update(pipelineConfigId: presetId).notifyUpdated()
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
        if let presetId: UInt64 = presetStore?.read(key: SettingKey.pipelinesConfigurationKey) {
            if presetId != currentId {
                sendConfigureCommand(presetId)
            }
            flightCameraRecorder.update(pipelineConfigId: presetId).notifyUpdated()
        } else {
            flightCameraRecorder.update(pipelineConfigId: currentId).notifyUpdated()
        }
    }

    /// Called when a command that notifies a pipelines configuration identifier change has been received.
    ///
    /// - Parameter id: new pipelines configuration identifier.
    func pipelinesConfigurationIdDidChange(_ id: UInt64) {
        currentId = id
        if connected {
            flightCameraRecorder.update(pipelineConfigId: id).notifyUpdated()
        }
    }

    /// Sets flight camera recording pipelines.
    ///
    /// - Parameter id: the new pipelines configuration identifier to set.
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(pipelineConfigId: UInt64) -> Bool {
        presetStore?.write(key: SettingKey.pipelinesConfigurationKey, value: pipelineConfigId).commit()
        if connected {
            sendConfigureCommand(pipelineConfigId)
            return true
        } else {
            flightCameraRecorder.update(pipelineConfigId: pipelineConfigId).notifyUpdated()
            return false
        }
    }

    /// Configure command
    ///
    /// - Parameter id: requested  pipeline configuration identifier.
    func sendConfigureCommand(_ id: UInt64) {
        sendCommand(ArsdkFeatureFcr.configurePipelinesEncoder(id: id))
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

    func onPipelines(id: UInt64) {
        pipelinesConfigurationIdDidChange(id)
    }
}
