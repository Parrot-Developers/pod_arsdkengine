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
import SwiftProtobuf

/// Return home delay min/max
private let autoStartOnDisconnectDelayMin = 0
private let autoStartOnDisconnectDelayMax = 120

/// Return home piloting interface component controller for the Anafi message based drones
class AnafiReturnHomePilotingItf: ActivablePilotingItfController {

    private static let settingKey = "ReturnHome"

    /// The piloting interface from which this object is the delegate
    internal var returnHomePilotingItf: ReturnHomePilotingItfCore {
        return pilotingItf as! ReturnHomePilotingItfCore
    }

    /// Store device specific values, like settings ranges and supported flags
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// if preferred target has been received.
    public var preferredTargetReceived = false

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case autoTriggerModeKey = "autoTriggerMode"
        case preferredTargetKey = "preferredTarget"
        case minAltitudeKey = "minAltitude"
        case endingHoveringAltitudeKey = "endingHoveringAltitude"
        case autoStartOnDisconnectDelayKey = "autoStartOnDisconnectDelay"
        case endingBehaviorKey = "wantedEndingBehavior"
    }

    enum Setting: Hashable {
        case autoTriggerMode(Bool)
        case preferredTarget(ReturnHomeTarget)
        case minAltitude(Double, Double, Double)
        case endingHoveringAltitude(Double, Double, Double)
        case autoStartOnDisconnectDelay(Int)
        case endingBehavior(ReturnHomeEndingBehavior)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .autoTriggerMode: return .autoTriggerModeKey
            case .preferredTarget: return .preferredTargetKey
            case .minAltitude: return .minAltitudeKey
            case .endingHoveringAltitude: return .endingHoveringAltitudeKey
            case .autoStartOnDisconnectDelay: return .autoStartOnDisconnectDelayKey
            case .endingBehavior: return .endingBehaviorKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [
            .autoTriggerMode(false),
            .preferredTarget(ReturnHomeTarget.takeOffPosition),
            .minAltitude(0, 0, 0),
            .endingHoveringAltitude(0, 0, 0),
            .autoStartOnDisconnectDelay(0),
            .endingBehavior(ReturnHomeEndingBehavior.landing)
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

    /// The home reachability as indicated by the drone.
    ///
    /// When there is no planned automatic return, the rthHomeReachability is reported in the interface. But when an
    /// automatic return is planned, the `homeReachability` property in the interface indicates .warning. So we memorize
    /// this value to be able to update the interface when a planned return date (`autoTriggerDate`) is reset to nil.
    var homeReachability = HomeReachability.unknown {
        didSet {
            if homeReachability != oldValue {
                updateReachabilityStatus()
            }
        }
    }

    /// If an automatic return is planned, indicates the "auto trigger delay".
    var autoTriggerDelay: TimeInterval? {
        didSet {
            if autoTriggerDelay != oldValue {
                updateReachabilityStatus()
            }
        }
    }

    /// Decoder for backup link events.
    private var arsdkDecoder: ArsdkBackuplinkEventDecoder!

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    /// Followee location.
    private var followeeLocation: ReturnHomeLocation?
    /// Custom location.
    private var customLocation: ReturnHomeLocation?
    /// Takeoff location.
    private var takeoffLocation: ReturnHomeLocation?
    /// Pilot location.
    private var pilotLocation: ReturnHomeLocation?
    /// Whether the home location event is supported or not
    private var isHomeLocationSupported = false

    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = activationController.droneController.deviceStore.getSettingsStore(
                key: AnafiReturnHomePilotingItf.settingKey)
            presetStore = activationController.droneController.presetStore.getSettingsStore(
                key: AnafiReturnHomePilotingItf.settingKey)
        }

        super.init(activationController: activationController)
        arsdkDecoder = ArsdkBackuplinkEventDecoder(listener: self)
        pilotingItf = ReturnHomePilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)

        loadPresets()
        if isPersisted {
            pilotingItf.publish()
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        super.willForget()
    }

    /// Drone is about to be connect
    override func willConnect() {
        super.willConnect()
        preferredTargetReceived = false
        // remove settings stored while connecting. We will get new one on the next connection.
        droneSettings.removeAll()
    }

    /// Drone is connected
    override func didConnect() {
        // We do not received Preferred home type when the drone first boot. So we need to apply
        // user setting.
        if !preferredTargetReceived {
            droneSettings.insert(.preferredTarget(.none))
        }
        storeNewPresets()
        applyPresets()
        returnHomePilotingItf.createCustomLocationSetting()
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        homeReachability = .unknown
        autoTriggerDelay = nil
        // clear all non saved settings
        returnHomePilotingItf.cancelSettingsRollback()
            .update(homeLocation: nil)
            .update(currentTarget: nil)
            .update(gpsFixedOnTakeOff: false)
            .update(unavailabilityReasons: nil)
            .update(suspended: false)
            .destroyCustomLocationSetting()

        if !isPersisted {
            pilotingItf.unpublish()
        }
        // super will call notifyUpdated
        super.didDisconnect()
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        returnHomePilotingItf.publish()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = activationController.droneController.presetStore.getSettingsStore(
            key: AnafiReturnHomePilotingItf.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        if connected {
            switch setting {
            case let .autoTriggerMode(value):
                returnHomePilotingItf.update(autoTriggerMode: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .preferredTarget(value):
                returnHomePilotingItf.update(preferredTarget: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .minAltitude(min, value, max):
                returnHomePilotingItf.update(minAltitude: (min, value, max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .endingHoveringAltitude(min, value, max):
                returnHomePilotingItf.update(endingHoveringAltitude: (min, value, max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .autoStartOnDisconnectDelay(value):
                returnHomePilotingItf.update(autoStartOnDisconnectDelay:
                                                (autoStartOnDisconnectDelayMin, value, autoStartOnDisconnectDelayMax))
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .endingBehavior(value):
                returnHomePilotingItf.update(endingBehavior: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            }
            pilotingItf.notifyUpdated()
            deviceStore?.commit()
        }
    }

    /// Load saved settings into pilotingItf
    private func loadPresets() {
        for setting in Setting.allCases {
            switch setting {
            case .autoTriggerMode:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Bool = presetStore.read(key: setting.key) {
                        returnHomePilotingItf.update(autoTriggerMode: value)
                    }
                }
            case .preferredTarget:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: ReturnHomeTarget = presetStore.read(key: setting.key) {
                        returnHomePilotingItf.update(preferredTarget: value)
                    }
                }
            case .minAltitude:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    returnHomePilotingItf.update(minAltitude: (range.min, value, range.max))
                }
            case .endingHoveringAltitude:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    returnHomePilotingItf.update(endingHoveringAltitude: (range.min, value, range.max))
                }
            case .autoStartOnDisconnectDelay:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Int = presetStore.read(key: setting.key) {
                        returnHomePilotingItf
                            .update(autoStartOnDisconnectDelay:
                                        (autoStartOnDisconnectDelayMin, value, autoStartOnDisconnectDelayMax))
                    }
                }
            case .endingBehavior:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: ReturnHomeEndingBehavior = presetStore.read(key: setting.key) {
                        returnHomePilotingItf.update(endingBehavior: value)
                    }
                }
            }
        }
        pilotingItf.notifyUpdated()
    }

    /// Called when the drone is connected, save all settings received during the connection and  not yet in the preset
    /// store, and all received settings ranges
    private func storeNewPresets() {
        if let deviceStore = deviceStore {
            for setting in droneSettings {
                switch setting {
                case .autoTriggerMode:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case .preferredTarget:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case let .minAltitude(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .endingHoveringAltitude(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .autoStartOnDisconnectDelay:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case .endingBehavior:
                    deviceStore.writeSupportedFlag(key: setting.key)
                }
            }
            deviceStore.commit()
        }
    }

    /// Applies presets.
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case let .autoTriggerMode(value):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendAutoTriggerModeCommand(active: preset)
                    }
                    returnHomePilotingItf.update(autoTriggerMode: preset)
                } else {
                    returnHomePilotingItf.update(autoTriggerMode: value)
                }
            case let .preferredTarget(value):
                if let preset: ReturnHomeTarget = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendPreferredTargetCommand(preset)
                    }
                    returnHomePilotingItf.update(preferredTarget: preset)
                } else {
                    returnHomePilotingItf.update(preferredTarget: value)
                }
            case let .minAltitude(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMinAltitudeCommand(preset)
                    }
                    returnHomePilotingItf.update(minAltitude: (min: min, value: preset, max: max))
                } else {
                    returnHomePilotingItf.update(minAltitude: (min: min, value: value, max: max))
                }
            case let .endingHoveringAltitude(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendEndingHoveringAltitudeCommand(preset)
                    }
                    returnHomePilotingItf.update(endingHoveringAltitude: (min: min, value: preset, max: max))
                } else {
                    returnHomePilotingItf.update(endingHoveringAltitude: (min: min, value: value, max: max))
                }
            case let .autoStartOnDisconnectDelay(value):
                if let preset: Int = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendHomeDelayCommand(preset)
                    }
                    returnHomePilotingItf
                        .update(autoStartOnDisconnectDelay:
                                    (autoStartOnDisconnectDelayMin, preset, autoStartOnDisconnectDelayMax))
                } else {
                    returnHomePilotingItf
                        .update(autoStartOnDisconnectDelay:
                                    (autoStartOnDisconnectDelayMin, value, autoStartOnDisconnectDelayMax))
                }
            case let .endingBehavior(value):
                if let preset: ReturnHomeEndingBehavior = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendWantedEndingBehaviorCommand(preset)
                    }
                    returnHomePilotingItf.update(endingBehavior: preset)
                } else {
                    returnHomePilotingItf.update(endingBehavior: value)
                }
            }
        }
        presetStore?.commit()
        pilotingItf.notifyUpdated()
    }

    /// Updates the homeReachability and the autoTriggerDelay.
    ///
    /// If an automatic return is planned, this function sets `homeReachability`to `.warning`.
    private func updateReachabilityStatus() {
        // force .warning if there is an autoTriggerDelay
        let reachability = autoTriggerDelay != nil ? .warning : homeReachability
        returnHomePilotingItf.update(homeReachability: reachability).update(autoTriggerDelay: autoTriggerDelay)
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureRthUid:
            ArsdkFeatureRth.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            arsdkDecoder.decode(command)
        default:
            break
        }
    }

    func sendCancelAutoTrigger() {
        _ = sendCommand(ArsdkFeatureRth.cancelAutoTriggerEncoder())
    }

    func sendCustomLocationCommand(latitude: Double, longitude: Double, altitude: Double) {
        _ = sendCommand(ArsdkFeatureRth.setCustomLocationEncoder(latitude: latitude,
                                                             longitude: longitude,
                                                             altitude: Float(altitude)))
    }

    /// Send preferred target command
    ///
    /// - Parameter preferredTarget: new preferred target
    func sendPreferredTargetCommand(_ preferredTarget: ReturnHomeTarget) {
        let homeType: ArsdkFeatureRthHomeType
        switch preferredTarget {
        case .none:
            homeType = .takeoff
        case .customPosition:
            homeType = .custom
        case .takeOffPosition:
            homeType = .takeoff
        case .controllerPosition:
            homeType = .pilot
        case .trackedTargetPosition:
            homeType = .followee
        }
        _ = sendCommand(ArsdkFeatureRth.setPreferredHomeTypeEncoder(type: homeType))
    }

    /// Send the command to activate/deactivate auto trigger return home
    ///
    /// - Parameter active: true to activate auto trigger return home, false to deactivate it
    func sendAutoTriggerModeCommand(active: Bool) {
        let mode: ArsdkFeatureRthAutoTriggerMode = active ? .on : .off
        _ = sendCommand(ArsdkFeatureRth.setAutoTriggerModeEncoder(mode: mode))
    }

    /// Send the wanted ending behavior command
    ///
    /// - Parameter wantedEndingBehavior: new wanted ending behavior
    func sendWantedEndingBehaviorCommand(_ wantedEndingBehavior: ReturnHomeEndingBehavior) {
        let endingBehavior: ArsdkFeatureRthEndingBehavior
        switch wantedEndingBehavior {
        case .landing:
            endingBehavior = .landing
        case .hovering:
            endingBehavior = .hovering
        }
        _ = sendCommand(ArsdkFeatureRth.setEndingBehaviorEncoder(endingBehavior: endingBehavior))
    }

    /// Send return home delay command
    ///
    /// - Parameter delay: new return home delay
    func sendHomeDelayCommand(_ delay: Int) {
        _ = sendCommand(ArsdkFeatureRth.setDelayEncoder(delay: UInt(delay)))
    }

    /// Send min altitude command
    ///
    /// - Parameter minAltitude: new min altitude
    func sendMinAltitudeCommand(_ minAltitude: Double) {
        _ = sendCommand(ArsdkFeatureRth.setMinAltitudeEncoder(
            altitude: Float(minAltitude)))
    }

    /// Send ending hovering altitude command
    ///
    /// - Parameter endingHoveringAltitude: new ending hovering altitude
    func sendEndingHoveringAltitudeCommand(_ endingHoveringAltitude: Double) {
        _ = sendCommand(ArsdkFeatureRth.setEndingHoveringAltitudeEncoder(altitude: Float(endingHoveringAltitude)))
    }

    /// Send the command to activate/deactivate return home
    ///
    /// - Parameter active: true to activate return home, false to deactivate it
    func sendReturnHomeCommand(active: Bool) {
        if active {
            _ = sendCommand(ArsdkFeatureRth.returnToHomeEncoder())
        } else {
            _ = sendCommand(ArsdkFeatureRth.abortEncoder())
        }
    }

    override func requestActivation() {
        sendReturnHomeCommand(active: true)
    }

    override func requestDeactivation() {
        sendReturnHomeCommand(active: false)
    }
}

/// AnafiReturnHomePilotingItf backend implementation
extension AnafiReturnHomePilotingItf: ReturnHomePilotingItfBackend {
    func activate() -> Bool {
        return droneController.pilotingItfActivationController.activate(pilotingItf: self)
    }

    func set(autoTriggerMode: Bool) -> Bool {
        guard !backupLinkIsActive else {
            returnHomePilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.autoTriggerModeKey, value: autoTriggerMode).commit()
        if connected {
            sendAutoTriggerModeCommand(active: autoTriggerMode)
            return true
        } else {
            returnHomePilotingItf.update(autoTriggerMode: autoTriggerMode).notifyUpdated()
            return false
        }
    }

    func cancelAutoTrigger() {
        guard !backupLinkIsActive else { return }
        sendCancelAutoTrigger()
    }

    func set(preferredTarget: ReturnHomeTarget) -> Bool {
        guard !backupLinkIsActive else {
            returnHomePilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.preferredTargetKey, value: preferredTarget).commit()
        if connected {
            sendPreferredTargetCommand(preferredTarget)
            return true
        } else {
            returnHomePilotingItf.update(preferredTarget: preferredTarget).notifyUpdated()
            return false
        }
    }

    func set(endingBehavior: ReturnHomeEndingBehavior) -> Bool {
        guard !backupLinkIsActive else {
            returnHomePilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.endingBehaviorKey, value: endingBehavior).commit()
        if connected {
            sendWantedEndingBehaviorCommand(endingBehavior)
            return true
        } else {
            returnHomePilotingItf.update(endingBehavior: endingBehavior).notifyUpdated()
            return false
        }
    }

    func set(endingHoveringAltitude: Double) -> Bool {
        guard !backupLinkIsActive else {
            returnHomePilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.endingHoveringAltitudeKey, value: endingHoveringAltitude).commit()
        if connected {
            sendEndingHoveringAltitudeCommand(endingHoveringAltitude)
            return true
        } else {
            returnHomePilotingItf.update(endingHoveringAltitude: (nil, endingHoveringAltitude, nil)).notifyUpdated()
            return false
        }
    }

    func set(customLocation: ReturnHomeLocation) -> Bool {
        guard !backupLinkIsActive else {
            returnHomePilotingItf.forceNotifyUpdated()
            return false
        }
        if connected {
            sendCustomLocationCommand(latitude: customLocation.latitude,
                                      longitude: customLocation.longitude,
                                      altitude: customLocation.altitude)
            return true
        }
        return false
    }

    func set(minAltitude: Double) -> Bool {
        guard !backupLinkIsActive else {
            returnHomePilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.minAltitudeKey, value: minAltitude).commit()
        if connected {
            sendMinAltitudeCommand(minAltitude)
            return true
        } else {
            returnHomePilotingItf.update(minAltitude: (nil, minAltitude, nil)).notifyUpdated()
            return false
        }
    }

    func set(autoStartOnDisconnectDelay: Int) -> Bool {
        guard !backupLinkIsActive else {
            returnHomePilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.autoStartOnDisconnectDelayKey, value: autoStartOnDisconnectDelay)
            .commit()
        if connected {
            sendHomeDelayCommand(autoStartOnDisconnectDelay)
            return true
        } else {
            returnHomePilotingItf
                .update(autoStartOnDisconnectDelay:
                            (autoStartOnDisconnectDelayMin, autoStartOnDisconnectDelay, autoStartOnDisconnectDelayMax))
                .notifyUpdated()
            return false
        }
    }
}

/// Anafi return home decode callback implementation
extension AnafiReturnHomePilotingItf: ArsdkFeatureRthCallback {
    func onState(state: ArsdkFeatureRthState, reason: ArsdkFeatureRthStateReason) {
        ULog.d(.tag, "ReturnHome: onState: state=\(state.rawValue) reason=\(reason.rawValue)")
        returnHomePilotingItf.update(suspended: state == .pending)
        switch state {
        case .available:
            let availabilityReason: ReturnHomeReason
            switch reason {
            case .finished:
                availabilityReason = .finished
            case .userRequest:
                availabilityReason = .userRequested
            case .blocked:
                availabilityReason = .blocked
            default:
                availabilityReason = .none
            }

            returnHomePilotingItf.update(reason: availabilityReason)
            if returnHomePilotingItf.unavailabilityReasons == nil
                || returnHomePilotingItf.unavailabilityReasons!.isEmpty {
                notifyIdle()
            } else {
                returnHomePilotingItf.notifyUpdated()
            }
        case .inProgress,
                .pending:
            // reset the auto trigger delay if any
            autoTriggerDelay = nil
            switch reason {
            case .userRequest:
                returnHomePilotingItf.update(reason: .userRequested)
                notifyActive()
            case .connectionLost:
                returnHomePilotingItf.update(reason: .connectionLost)
                notifyActive()
            case .lowBattery:
                returnHomePilotingItf.update(reason: .powerLow)
                notifyActive()
            case .icing:
                returnHomePilotingItf.update(reason: .icedPropeller)
                notifyActive()
            case .batteryLostComm:
                returnHomePilotingItf.update(reason: .batteryPoorConnection)
                notifyActive()
            case .batteryTooHot:
                returnHomePilotingItf.update(reason: .batteryTooHot)
                notifyActive()
            case .finished,
                    .stopped,
                    .enabled,
                    .disabled:
                returnHomePilotingItf.update(reason: .none)
                notifyActive()
            case .motorDown:
                returnHomePilotingItf.update(reason: .motorDown)
            case .flightplan:
                returnHomePilotingItf.update(reason: .flightplan)
            case .blocked:
                // ignore this event
                break
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                // don't change anything if value is unknown
                ULog.w(.tag, "Unknown reason, reason won't be modified and might be wrong.")
                notifyActive()
            }
        case .unavailable:
            returnHomePilotingItf.update(reason: .none)
            notifyUnavailable()
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown navigate home state, skipping this event.")
            return
        }
        pilotingItf.notifyUpdated()
    }

    func onAutoTriggerMode(mode: ArsdkFeatureRthAutoTriggerMode) {
        switch mode {
        case .off:
            settingDidChange(.autoTriggerMode(false))
        case .on:
            settingDidChange(.autoTriggerMode(true))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthAutoTriggerMode, skipping this event.")
        }
    }

    func onEndingBehavior(endingBehavior: ArsdkFeatureRthEndingBehavior) {
        switch endingBehavior {
        case .landing:
            settingDidChange(.endingBehavior(.landing))
        case .hovering:
            settingDidChange(.endingBehavior(.hovering))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthEndingBehavior, skipping this event.")
        }
    }

    func onEndingHoveringAltitude(current: Float, min: Float, max: Float) {
        ULog.d(.tag, "ReturnHome: onEndingHoveringAltitude: current=\(current). min=\(min), max= \(max)")
        settingDidChange(.endingHoveringAltitude(Double(min), Double(current), Double(max)))
    }

    func onHomeReachability(status: ArsdkFeatureRthHomeReachability) {
        switch status {
        case .reachable:
            homeReachability = .reachable
        case .notReachable:
            homeReachability = .notReachable
        case .critical:
            homeReachability = .critical
        case .unknown:
            homeReachability = .unknown
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthHomeReachability, skipping this event.")
        }
        returnHomePilotingItf.notifyUpdated()
    }

    func onRthAutoTrigger(reason: ArsdkFeatureRthAutoTriggerReason, delay: UInt) {
        switch reason {
        case .sdkCoreUnknown:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureRthAutoTriggerReason, skipping this event.")
            return
        case .none:
            autoTriggerDelay = nil
        @unknown default:
            autoTriggerDelay = TimeInterval(delay)
        }

        returnHomePilotingItf.notifyUpdated()
    }

    func onPreferredHomeType(type: ArsdkFeatureRthHomeType) {
        self.preferredTargetReceived = true
        switch type {
        case .none:
            settingDidChange(.preferredTarget(.none))
        case .takeoff:
            settingDidChange(.preferredTarget(.takeOffPosition))
        case .followee:
            settingDidChange(.preferredTarget(.trackedTargetPosition))
        case .custom:
            settingDidChange(.preferredTarget(.customPosition))
        case .pilot:
            settingDidChange(.preferredTarget(.controllerPosition))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown home type, skipping this event.")
            return
        }
    }

    func onHomeType(type: ArsdkFeatureRthHomeType) {
        ULog.d(.tag, "ReturnHome: onHomeType: type=\(type.rawValue)")
        if let type = ReturnHomeTarget(fromArsdk: type) {
            returnHomePilotingItf.update(currentTarget: type)
            if !isHomeLocationSupported {
                updateLocation(target: type)
            }
            returnHomePilotingItf.notifyUpdated()
        }
    }

    func onCustomLocation(latitude: Double, longitude: Double, altitude: Float) {
        customLocation = checkLocation(location: ReturnHomeLocation(latitude: latitude, longitude: longitude,
                                                                    altitude: Double(altitude)))
        returnHomePilotingItf.createCustomLocationSetting()
            .update(customLocation: customLocation)

        if !isHomeLocationSupported {
            updateLocation(target: returnHomePilotingItf.currentTarget)
        }
        returnHomePilotingItf.notifyUpdated()
    }

    func onHomeLocation(latitude: Double, longitude: Double, altitude: Float) {
        isHomeLocationSupported = true
        let homeLocation = checkLocation(location: ReturnHomeLocation(latitude: latitude, longitude: longitude,
                                                                      altitude: Double(altitude)))
        returnHomePilotingItf.update(homeLocation: homeLocation)
        returnHomePilotingItf.notifyUpdated()
    }

    func onTakeoffLocation(latitude: Double, longitude: Double, altitude: Float, fixedBeforeTakeoff: UInt) {
        returnHomePilotingItf.update(gpsFixedOnTakeOff: (fixedBeforeTakeoff != 0))
        if !isHomeLocationSupported {
            takeoffLocation = checkLocation(location: ReturnHomeLocation(latitude: latitude, longitude: longitude,
                                                                         altitude: Double(altitude)))
            updateLocation(target: returnHomePilotingItf.currentTarget)
        }
        returnHomePilotingItf.notifyUpdated()
    }

    func onFolloweeLocation(latitude: Double, longitude: Double, altitude: Float) {
        guard !isHomeLocationSupported else { return }
        followeeLocation = checkLocation(location: ReturnHomeLocation(latitude: latitude, longitude: longitude,
                                                                      altitude: Double(altitude)))
        updateLocation(target: returnHomePilotingItf.currentTarget)
        returnHomePilotingItf.notifyUpdated()
    }

    func onPilotLocation(latitude: Double, longitude: Double, altitude: Float) {
        guard !isHomeLocationSupported else { return }
        pilotLocation = checkLocation(location: ReturnHomeLocation(latitude: latitude, longitude: longitude,
                                                                   altitude: Double(altitude)))
        updateLocation(target: returnHomePilotingItf.currentTarget)
        returnHomePilotingItf.notifyUpdated()
    }

    func checkLocation(location: ReturnHomeLocation) -> ReturnHomeLocation? {
            if !location.latitude.isNaN && !location.longitude.isNaN
                && location.latitude != AnafiReturnHomePilotingItf.UnknownCoordinate
                && location.longitude != AnafiReturnHomePilotingItf.UnknownCoordinate {
            return location
        } else { return nil}
    }

    /// Update the home location depending on the target.
    ///
    /// - Parameter target: the return home target
    private func updateLocation(target: ReturnHomeTarget?) {
        guard let target else { return }

        switch target {
        case .none:
            returnHomePilotingItf.update(homeLocation: nil)
        case .controllerPosition:
            returnHomePilotingItf.update(homeLocation: pilotLocation)
        case .takeOffPosition:
            returnHomePilotingItf.update(homeLocation: takeoffLocation)
        case .trackedTargetPosition:
            returnHomePilotingItf.update(homeLocation: followeeLocation)
        case .customPosition:
            returnHomePilotingItf.update(homeLocation: customLocation)
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown home type, skipping this event.")
            return
        }
    }

    func onDelay(delay: UInt, min: UInt, max: UInt) {
        ULog.d(.tag, "ReturnHome: onReturnHomeDelayChanged: delay=\(delay)")
        settingDidChange(.autoStartOnDisconnectDelay(Int(delay)))
    }

    func onMinAltitude(current: Float, min: Float, max: Float) {
        ULog.d(.tag, "ReturnHome: onMinAltitude: value=\(current). min=\(min), max= \(max)")
        settingDidChange(.minAltitude(Double(min), Double(current), Double(max)))
    }

    func onInfo(missingInputsBitField: UInt) {
        returnHomePilotingItf.update(
            unavailabilityReasons: ReturnHomeIssue.createSetFrom(bitField: missingInputsBitField))

        if returnHomePilotingItf.unavailabilityReasons!.isEmpty {
            if returnHomePilotingItf.state != .active {
                notifyIdle()
            }
        } else {
            notifyUnavailable()
        }
        returnHomePilotingItf.notifyUpdated()
    }

    func onHomeTypeCapabilities(valuesBitField: UInt) {
        returnHomePilotingItf.update(preferredTargetSupportedValues: ReturnHomeTarget
            .createSetFrom(bitField: valuesBitField))
        returnHomePilotingItf.notifyUpdated()
    }
}

/// Extension to decode ArsdkBackuplinkEvent
extension AnafiReturnHomePilotingItf: ArsdkBackuplinkEventDecoderListener {
    func onTelemetry(_ telemetry: Arsdk_Backuplink_Event.Telemetry) {
        if telemetry.flyingState == .rth {
            notifyActive()
        } else {
            notifyIdle()
        }
    }

    func onMainRadioDisconnecting(_ mainRadioDisconnecting: SwiftProtobuf.Google_Protobuf_Empty) {
        // nothing to do
    }
}

/// Extension that add conversion from/to arsdk enum
extension ReturnHomeIssue: ArsdkMappableEnum {

    /// Create set of return home issues from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all return home issues set in bitField
    static func createSetFrom(bitField: UInt) -> Set<ReturnHomeIssue> {
        var result = Set<ReturnHomeIssue>()
        ArsdkFeatureRthIndicatorBitField.forAllSet(in: bitField) { arsdkValue in
            if let missing = ReturnHomeIssue(fromArsdk: arsdkValue) {
                result.insert(missing)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<ReturnHomeIssue, ArsdkFeatureRthIndicator>([
        .droneGpsInfoInaccurate: .droneGps,
        .droneNotCalibrated: .droneMagneto,
        .droneNotFlying: .droneFlying
    ])
}

/// Extension that add conversion from/to arsdk enum
extension ReturnHomeTarget: ArsdkMappableEnum {
    /// Create set of return home target from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all return home issues set in bitField
    static func createSetFrom(bitField: UInt) -> Set<ReturnHomeTarget> {
        var result = Set<ReturnHomeTarget>()
        ArsdkFeatureRthHomeTypeBitField.forAllSet(in: bitField) { arsdkValue in
            if let missing = ReturnHomeTarget(fromArsdk: arsdkValue) {
                result.insert(missing)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<ReturnHomeTarget, ArsdkFeatureRthHomeType>([
        .customPosition: .custom,
        .trackedTargetPosition: .followee,
        .none: .none,
        .controllerPosition: .pilot,
        .takeOffPosition: .takeoff
        ])
}

/// Extension to make ReturnHomeTarget storable
extension ReturnHomeTarget: StorableEnum {
    static let storableMapper = Mapper<ReturnHomeTarget, String>([
        .takeOffPosition: "takeOff",
        .controllerPosition: "controller",
        .trackedTargetPosition: "trackedTargetPosition",
        .customPosition: "customPosition",
        .none: "none"])
}

/// Extension to make ReturnHomeEndingBehavior storable
extension ReturnHomeEndingBehavior: StorableEnum {
    static let storableMapper = Mapper<ReturnHomeEndingBehavior, String>([
        .landing: "landing",
        .hovering: "hovering"])
}
