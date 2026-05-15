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
import CoreLocation

/// Base controller for geofence peripheral
class AnafiGeofence: DeviceComponentController, GeofenceBackend {

    /// Component settings key
    private static let settingKey = "Geofence"

    /// Geofence component
    private(set) var geofence: GeofenceCore!

    /// Whether ArsdkGeofence messages are supported by the drone.
    private var isArsdkGeofenceSupported: Bool = false

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// All setting backends of this peripheral
    private var settings = [OfflineSetting]()

    /// Max altitude setting backend
    internal var maxAltitudeSetting: OfflineDoubleSetting!

    /// Max distance setting backend
    internal var maxDistanceSetting: OfflineDoubleSetting!

    /// Mode setting backend
    internal var modeSetting: OfflineEnumSetting<GeofenceMode>!

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case maxAltitude = "maxAltitude"
        case maxDistance = "maxDistance"
        case mode = "mode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case maxAltitude(Double, Double, Double)
        case maxDistance(Double, Double, Double)
        case mode(GeofenceMode)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .mode
            case .maxAltitude: return .maxAltitude
            case .maxDistance: return .maxDistance
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [
            .maxAltitude(0, 0, 0),
            .maxDistance(0, 0, 0),
            .mode(.altitude)
        ]
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Decoder for geofence events.
    private var geofenceDecoder: ArsdkGeofenceEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: AnafiGeofence.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: AnafiGeofence.settingKey)
        }

        super.init(deviceController: deviceController)
        geofenceDecoder = ArsdkGeofenceEventDecoder(listener: self)
        geofence = GeofenceCore(store: deviceController.device.peripheralStore, backend: self)
        prepareOfflineSettings()
        if isPersisted {
            geofence.publish()
        }
    }

    public func prepareOfflineSettings() {
        modeSetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.mode,
            setting: geofence.mode as! EnumSettingCore,
            notifyComponent: { self.geofence.notifyUpdated() },
            markChanged: { self.geofence.markChanged() },
            sendCommand: { mode in
                return self.sendModeCommand(mode)
            })

        maxAltitudeSetting = OfflineDoubleSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.maxAltitude,
            setting: geofence.maxAltitude as! DoubleSettingCore,
            notifyComponent: { self.geofence.notifyUpdated() },
            markChanged: { self.geofence.markChanged() },
            sendCommand: { maxAltitude in
                return self.sendMaxAltitudeCommand(maxAltitude)
            }
        )

        maxDistanceSetting = OfflineDoubleSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.maxDistance,
            setting: geofence.maxDistance as! DoubleSettingCore,
            notifyComponent: { self.geofence.notifyUpdated() },
            markChanged: { self.geofence.markChanged() },
            sendCommand: { maxDistance in
                return self.sendMaxDistanceCommand(maxDistance)
            }
        )
        settings = [modeSetting!, maxAltitudeSetting!, maxDistanceSetting!]
    }

    /// Send max altitude settings
    ///
    /// - Parameter maxAltitude: new maximum altitude
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxAltitude value: Double) -> Bool {
        guard !backupLinkIsActive else {
            geofence.forceNotifyUpdated()
            return false
        }
        return maxAltitudeSetting!.setValue(value: value)
    }

    /// Send max distance settings
    ///
    /// - Parameter maxDistance: new maximum distance
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxDistance value: Double) -> Bool {
        guard !backupLinkIsActive else {
            geofence.forceNotifyUpdated()
            return false
        }
        return maxDistanceSetting!.setValue(value: value)
    }

    /// Send mode setting
    ///
    /// - Parameter mode: new geofencing mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode value: GeofenceMode) -> Bool {
        guard !backupLinkIsActive else {
            geofence.forceNotifyUpdated()
            return false
        }
        return modeSetting!.setValue(value: value)
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        geofence.unpublish()
        super.willForget()
    }

    /// Drone is about to be connect
    override func willConnect() {
        super.willConnect()
        isArsdkGeofenceSupported = false
        // remove settings stored while connecting. We will get new one on the next connection.
        settings.forEach { setting in
            setting.resetDeviceValue()
        }
        _ = sendGeofenceGetStateCommand()
    }

    /// Drone is connected
    override func didConnect() {
        geofence.publish()
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        geofence.update(center: nil).update(isAvailable: nil)
        geofence.cancelSettingsRollback()

        if isPersisted {
            geofence.publish()
        } else {
            geofence.unpublish()
        }
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        geofence.publish()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        if connected {
            settings.forEach { setting in
                setting.applyPreset()
            }
        }
        geofence.notifyUpdated()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        let featureId = ArsdkCommand.getFeatureId(command)
        switch featureId {
        case kArsdkFeatureArdrone3PilotingsettingsstateUid:
            // Piloting Settings
            ArsdkFeatureArdrone3Pilotingsettingsstate.decode(command, callback: self)
        case kArsdkFeatureArdrone3GpssettingsstateUid:
            // Piloting Settings
            ArsdkFeatureArdrone3Gpssettingsstate.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            geofenceDecoder.decode(command)
        default: break
        }
    }
}

// MARK: - AnafiGeofence - Commands
extension AnafiGeofence {
    /// Send set max altitude command.
    ///
    /// - Parameter value: new value
    /// - Returns: `true` if the command has been sent
    func sendMaxAltitudeCommand(_ value: Double) -> Bool {
        ULog.d(.ctrlTag, "Geofence: setting max atlitude: \(value)")
        if isArsdkGeofenceSupported {
            var setMaxAltitude = Arsdk_Geofence_Command.SetMaxAltitude()
            setMaxAltitude.value = Float(value)
            return sendGeofenceCommand(.setMaxAltitude(setMaxAltitude))
        } else {
            return sendCommand(ArsdkFeatureArdrone3Pilotingsettings.maxAltitudeEncoder(current: Float(value)))
        }
    }

    /// Send set max distance command.
    ///
    /// - Parameter value: new value
    /// - Returns: `true` if the command has been sent
    func sendMaxDistanceCommand(_ value: Double) -> Bool {
        ULog.d(.ctrlTag, "Geofence: setting max distance: \(value)")
        if isArsdkGeofenceSupported {
            var setMaxDistance = Arsdk_Geofence_Command.SetMaxDistance()
            setMaxDistance.value = Float(value)
            return sendGeofenceCommand(.setMaxDistance(setMaxDistance))
        } else {
            return sendCommand(ArsdkFeatureArdrone3Pilotingsettings.maxDistanceEncoder(value: Float(value)))
        }
    }

    /// Send set mode command.
    ///
    /// - Parameter mode: new mode
    /// - Returns: `true` if the command has been sent
    func sendModeCommand(_ mode: GeofenceMode) -> Bool {
        ULog.d(.ctrlTag, "Geofence: setting mode: \(mode)")
        if isArsdkGeofenceSupported {
            var setMode = Arsdk_Geofence_Command.SetMode()
            setMode.value = mode.arsdkValue!
            return sendGeofenceCommand(.setMode(setMode))
        } else {
            return sendCommand(ArsdkFeatureArdrone3Pilotingsettings.noFlyOverMaxDistanceEncoder(
                shouldnotflyover: mode == .cylinder ? 1 : 0))
        }
    }

    /// Sends geofence get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGeofenceGetStateCommand() -> Bool {
        var getState = Arsdk_Geofence_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendGeofenceCommand(.getState(getState))
    }

    /// Sends to the drone a Geofence command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendGeofenceCommand(_ command: Arsdk_Geofence_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkGeofenceCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Piloting Settings callback implementation
extension AnafiGeofence: ArsdkFeatureArdrone3PilotingsettingsstateCallback {
    func onMaxAltitudeChanged(current: Float, min: Float, max: Float) {
        guard !isArsdkGeofenceSupported else { return }
        guard min <= max else {
            ULog.w(.tag, "Max altitude bounds are not correct, skipping this event.")
            return
        }
        maxAltitudeSetting.handleNewBounds(min: Double(min), max: Double(max))
        maxAltitudeSetting.handleNewValue(value: Double(current))
        geofence.notifyUpdated()
    }

    func onMaxDistanceChanged(current: Float, min: Float, max: Float) {
        guard !isArsdkGeofenceSupported else { return }
        guard min <= max else {
            ULog.w(.tag, "Max distance bounds are not correct, skipping this event.")
            return
        }
        maxDistanceSetting.handleNewBounds(min: Double(min), max: Double(max))
        maxDistanceSetting.handleNewValue(value: Double(current))
        geofence.notifyUpdated()
    }

    func onNoFlyOverMaxDistanceChanged(shouldnotflyover: UInt) {
        guard !isArsdkGeofenceSupported else { return }
        ULog.d(.ctrlTag, "AnafiGeofence: onNoFlyOverMaxDistanceChanged: \(shouldnotflyover)")
        modeSetting.handleNewAvailableValues(values: [.cylinder, .altitude])
        modeSetting.handleNewValue(value: shouldnotflyover == 1 ? .cylinder : .altitude)
        geofence.notifyUpdated()
    }
}

// GPS Settings callback implementation
extension AnafiGeofence: ArsdkFeatureArdrone3GpssettingsstateCallback {

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    func onGeofenceCenterChanged(latitude: Double, longitude: Double) {
        guard !isArsdkGeofenceSupported else { return }
        updateGeofenceCenter(latitude: latitude, longitude: longitude)
    }

    /// Updates geofence center.
    ///
    /// Clears current peripheral geofence center in case any of the coordinate is UnknownCoordinate.
    ///
    /// - Parameters:
    ///     - latitude: new latitude
    ///     - longitude: new longitude
    private func updateGeofenceCenter(latitude: Double, longitude: Double) {
        if latitude != AnafiGeofence.UnknownCoordinate && longitude != AnafiGeofence.UnknownCoordinate {
            geofence.update(center: CLLocation(latitude: latitude, longitude: longitude))
        } else {
            geofence.update(center: nil)
        }
        geofence.notifyUpdated()
    }
}

extension AnafiGeofence: ArsdkGeofenceEventDecoderListener {
    func onState(_ state: Arsdk_Geofence_Event.State) {
        isArsdkGeofenceSupported = true
        if state.hasDefaultCapabilities {
            let modes = state.defaultCapabilities.modes
                .compactMap { GeofenceMode(fromArsdk: $0) }
            modeSetting.handleNewAvailableValues(values: Set(modes))

            if state.defaultCapabilities.hasMaxAltitudeRange {
                maxAltitudeSetting.handleNewBounds(
                    min: Double(state.defaultCapabilities.maxAltitudeRange.min),
                    max: Double(state.defaultCapabilities.maxAltitudeRange.max))
            }

            if state.defaultCapabilities.hasMaxDistanceRange {
                maxDistanceSetting.handleNewBounds(min: Double(state.defaultCapabilities.maxDistanceRange.min),
                                                max: Double(state.defaultCapabilities.maxDistanceRange.max))
            }
        }
        if state.hasIsAvailable {
            geofence.update(isAvailable: state.isAvailable.value)
        }
        if state.hasMode {
            modeSetting.handleNewValue(value: GeofenceMode(fromArsdk: state.mode.value))
        }
        if state.hasCenter {
            if state.center.hasCoordinates {
                geofence.update(center: CLLocation(latitude: state.center.coordinates.latitude,
                                                   longitude: state.center.coordinates.longitude))
            } else {
                geofence.update(center: nil)
            }
        }

        if state.hasMaxAltitude {
            maxAltitudeSetting.handleNewValue(value: Double(state.maxAltitude.value))
        }

        if state.hasMaxDistance {
            maxDistanceSetting.handleNewValue(value: Double(state.maxDistance.value))

        }
        geofence.notifyUpdated()
    }
}

// Extension to make GeofenceMode storable
extension GeofenceMode: StorableEnum {
    static var storableMapper = Mapper<GeofenceMode, String>([
        .altitude: "altitude",
        .cylinder: "cylinder"])
}

/// Extension that adds conversion from/to arsdk enum.
extension GeofenceMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<GeofenceMode, Arsdk_Geofence_Mode>([
        .altitude: .altitude,
        .cylinder: .cylinder
    ])
}
