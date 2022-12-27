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

/// Controller for obstacle avoidance peripheral.
class ObstacleAvoidanceController: DeviceComponentController, ObstacleAvoidanceBackend {

    /// Obstacle avoidance component.
    private var obstacleAvoidance: ObstacleAvoidanceCore!

    /// Whether connected drone supports obstacle avoidance.
    private var obstacleAvoidanceSupported = false

    /// component settings key
    private static let settingKey = "ObstacleAvoidanceController"

     /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case preferredModeKey = "preferredMode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case preferredMode(ObstacleAvoidanceMode)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .preferredMode: return .preferredModeKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: Set<Setting> = [.preferredMode(.disabled)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Preset store for this obstacle avoidance interface
    private var presetStore: SettingsStore?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {

        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            presetStore = nil
        } else {
            presetStore = deviceController.presetStore.getSettingsStore(key: ObstacleAvoidanceController.settingKey)
        }

        super.init(deviceController: deviceController)
        obstacleAvoidance = ObstacleAvoidanceCore(store: deviceController.device.peripheralStore, backend: self)
        // load settings
        if let presetStore = presetStore, !presetStore.new {
            loadPresets()
            obstacleAvoidance.publish()
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore {
            Setting.allCases.forEach {
                switch $0 {
                case .preferredMode:
                    if let preferredMode: ObstacleAvoidanceMode = presetStore.read(key: $0.key) {
                        obstacleAvoidance.update(preferredMode: preferredMode).notifyUpdated()
                    }
                }
            }
        }
    }

    /// Drone is about to be connected.
    override func willConnect() {
        super.willConnect()
        // remove settings stored while connecting. We will get new ones on the next connection.
        droneSettings.removeAll()
    }

    /// Drone is connected.
    override func didConnect() {
        applyPresets()
        if obstacleAvoidanceSupported {
            obstacleAvoidance.publish()
        } else {
            obstacleAvoidance.unpublish()
        }
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        obstacleAvoidanceSupported = false

        obstacleAvoidance.cancelSettingsRollback()
        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            obstacleAvoidance.unpublish()
        }
        obstacleAvoidance.update(state: .inactive).notifyUpdated()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: ObstacleAvoidanceController.settingKey)
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
            case .preferredMode(let preferredMode):
                if let preset: ObstacleAvoidanceMode = presetStore?.read(key: setting.key) {
                    if preset != preferredMode {
                        _ = sendSetModeCommand(preset)
                    }
                    obstacleAvoidance.update(preferredMode: preset).notifyUpdated()
                } else {
                    obstacleAvoidance.update(preferredMode: preferredMode).notifyUpdated()
                }
            }
        }
    }

    /// Called when a command that notifies a setting change has been received
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .preferredMode(let preferredMode):
            if connected {
                obstacleAvoidance.update(preferredMode: preferredMode)
            }
        }
        obstacleAvoidance.notifyUpdated()
    }

    func set(preferredMode: ObstacleAvoidanceMode) -> Bool {
        presetStore?.write(key: SettingKey.preferredModeKey, value: preferredMode).commit()
        if connected {
            return sendSetModeCommand(preferredMode)
        } else {
            obstacleAvoidance.update(preferredMode: preferredMode).notifyUpdated()
            return false
        }
    }

    /// Set mode command
    ///
    /// - Parameter mode: requested mode.
    /// - Returns: true if the command has been sent
    func sendSetModeCommand(_ mode: ObstacleAvoidanceMode) -> Bool {
        if obstacleAvoidance.mode.supportedValues.contains(mode) {
            switch mode {
            case .disabled:
                sendCommand(ArsdkFeatureObstacleAvoidance.setModeEncoder(mode: .disabled))
            case .standard:
                sendCommand(ArsdkFeatureObstacleAvoidance.setModeEncoder(mode: .standard))
            }
            return true
        } else {
            return false
        }
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureObstacleAvoidanceUid {
            ArsdkFeatureObstacleAvoidance.decode(command, callback: self)
        }
    }
}

/// Obstacle avoidance decode callback implementation.
extension ObstacleAvoidanceController: ArsdkFeatureObstacleAvoidanceCallback {

    func onStatus(mode: ArsdkFeatureObstacleAvoidanceMode, state: ArsdkFeatureObstacleAvoidanceState,
                  availability: ArsdkFeatureObstacleAvoidanceAvailability) {
        obstacleAvoidanceSupported = true

        guard let mode = ObstacleAvoidanceMode(fromArsdk: mode) else {
            ULog.w(.tag, "Unknown ArsdkFeatureObstacleAvoidanceMode, skipping this event.")
            return
        }
        guard let state = ObstacleAvoidanceState(fromArsdk: state) else {
            ULog.w(.tag, "Unknown ArsdkFeatureObstacleAvoidanceState, skipping this event.")
            return
        }
        obstacleAvoidance.update(state: state)
        settingDidChange(.preferredMode(mode))
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension ObstacleAvoidanceMode: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<ObstacleAvoidanceMode, ArsdkFeatureObstacleAvoidanceMode>([
        .disabled: .disabled,
        .standard: .standard
        ])
}

extension ObstacleAvoidanceMode: StorableEnum {
    static let storableMapper = Mapper<ObstacleAvoidanceMode, String>([
        .disabled: "disabled",
        .standard: "standard"])
}

/// Extension that adds conversion from/to arsdk enum.
extension ObstacleAvoidanceState: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<ObstacleAvoidanceState, ArsdkFeatureObstacleAvoidanceState>([
        .active: .active,
        .inactive: .inactive,
        .degraded: .degraded
        ])
}
