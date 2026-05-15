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

/// Leds supported capabilities
public enum LedsSupportedCapabilities: Int, CustomStringConvertible {

    /// Leds state is off
    case onOff

    /// Infrared leds state
    case infrared

    /// Debug description.
    public var description: String {
        switch self {
        case .onOff:         return "onOff"
        case .infrared:      return "infrared"
        }
    }

    /// Comparator
    public static func < (lhs: LedsSupportedCapabilities, rhs: LedsSupportedCapabilities) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    /// Set containing all possible values
    public static let allCases: Set<LedsSupportedCapabilities> = [
        .onOff, .infrared]

}

/// Leds support.
public enum LedsSupport: String, CustomStringConvertible, CaseIterable {
    /// Leds is unsupported (e.g. legacy capabilities bitfield is empty).
    case unsupported
    /// Legacy Leds support via `ArsdkFeatureLeds`.
    case legacy
    /// Leds support via `Led` proto messages
    case proto
    /// Debug description.
    public var description: String { rawValue }
}

/// Base controller for leds peripheral
class LedsController: DeviceComponentController, LedsBackend {

    /// Leds component
    private var leds: LedsCore!

    /// component settings key
    private static let settingKey = "LedsController"

    /// Preset store for this leds interface
    private var presetStore: SettingsStore?

    /// Device store for this leds interface
    private var deviceStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case stateKey = "state"
        case infraredKey = "infrared"
        case tofKey = "tof"
    }

    /// Stored settings
    enum Setting: Hashable {
        case state(Bool)
        case infrared(Bool)
        case tof(Bool)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .state: return .stateKey
            case .infrared: return .infraredKey
            case .tof: return .tofKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: Set<Setting> = [.state(false), .infrared(false)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Decoder for led events.
    private var arsdkLedDecoder: ArsdkLedEventDecoder!

    /// All setting backends of this peripheral
    private var settings = [OfflineSetting]()

    /// Standard leds setting backend
    internal var standardSetting: OfflineBoolSetting?

    /// Infrared leds setting backend
    internal var infraredSetting: OfflineBoolSetting?

    /// ToF leds setting backend
    internal var tofSetting: OfflineBoolSetting?

    /// Leds support and protocol selection for the current connection.
    private(set) public var ledsSupport = LedsSupport.unsupported

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: LedsController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: LedsController.settingKey)
        }

        super.init(deviceController: deviceController)
        arsdkLedDecoder = ArsdkLedEventDecoder(listener: self)
        leds = LedsCore(store: deviceController.device.peripheralStore, backend: self)

        // load settings
        if deviceStore?.read(key: SettingKey.stateKey) == true {
            leds.createStandard()
            prepareOfflineSettingStandard()
        }
        if deviceStore?.read(key: SettingKey.infraredKey) == true {
            leds.createInfrared()
            prepareOfflineSettingInfrared()
        }
        if deviceStore?.read(key: SettingKey.tofKey) == true {
            leds.createTof()
            prepareOfflineSettingTof()
        }

        if isPersisted {
            leds.publish()
        }
    }

    private func prepareOfflineSettingStandard() {
        if standardSetting == nil {
            standardSetting = OfflineBoolSetting(
                presetDict: presetStore, presetEntry: SettingKey.stateKey,
                setting: leds.standard as! BoolSettingCore,
                notifyComponent: {
                    self.leds.notifyUpdated()
                }, markChanged: {
                    self.leds.markChanged()
                }, sendCommand: { enabled in
                    self.sendStandardCommand(enabled)
                })
            settings.append(standardSetting!)
        }
    }

    private func prepareOfflineSettingInfrared() {
        if infraredSetting == nil {
            infraredSetting = OfflineBoolSetting(
                presetDict: presetStore, presetEntry: SettingKey.infraredKey,
                setting: leds.infrared as! BoolSettingCore,
                notifyComponent: {
                    self.leds.notifyUpdated()
                }, markChanged: {
                    self.leds.markChanged()
                }, sendCommand: { enabled in
                    self.sendInfraredCommand(enabled)
                })
            settings.append(infraredSetting!)
        }
    }

    private func prepareOfflineSettingTof() {
        if tofSetting == nil {
            tofSetting = OfflineBoolSetting(
                presetDict: presetStore, presetEntry: SettingKey.tofKey,
                setting: leds.tof as! BoolSettingCore,
                notifyComponent: {
                    self.leds.notifyUpdated()
                }, markChanged: {
                    self.leds.markChanged()
                }, sendCommand: { enabled in
                    self.sendSwitchCommand(type: .tof, enabled: enabled)
                })
            settings.append(tofSetting!)
        }
    }

    func set(standard: Bool) -> Bool {
        return standardSetting?.setValue(value: standard) == true
    }

    func set(infrared: Bool) -> Bool {
        return infraredSetting?.setValue(value: infrared) == true
    }

    func set(tof: Bool) -> Bool {
        return tofSetting?.setValue(value: tof) == true
    }

    /// Sends standard leds Activation or deactivation command
    ///
    /// - Parameter enabled: requested state
    /// - Returns: `true` if the command has been sent
    func sendStandardCommand(_ enabled: Bool) -> Bool {
        if ledsSupport == .proto {
            return sendSwitchCommand(type: .standard, enabled: enabled)
        } else {
            if enabled {
                return sendCommand(ArsdkFeatureLeds.activateEncoder())
            } else {
                return sendCommand(ArsdkFeatureLeds.deactivateEncoder())
            }
        }
    }

    /// Sends infrared leds Activation or deactivation command
    ///
    /// - Parameter enabled: requested state
    /// - Returns: `true` if the command has been sent
    func sendInfraredCommand(_ enabled: Bool) -> Bool {
        if ledsSupport == .proto {
            return sendSwitchCommand(type: .infrared, enabled: enabled)
        } else {
            return sendCommand(ArsdkFeatureLeds.setIrStateEncoder(ledState: enabled ? .on : .off))
        }
    }

    override func willConnect() {
        ledsSupport = .unsupported
        // remove settings stored while connecting; we will get new one on next connection
        settings.forEach { setting in
            setting.resetDeviceValue()
        }
        _ = sendGetStateCommand()
    }

    override func didConnect() {
        if ledsSupport != LedsSupport.unsupported {
            leds.publish()
        } else {
            leds.unpublish()
        }
    }

    override func didDisconnect() {
        leds.cancelSettingsRollback()
        if isPersisted {
            leds.notifyUpdated()
        } else {
            leds.unpublish()
        }
    }

    override func willForget() {
        standardSetting = nil
        infraredSetting = nil
        tofSetting = nil
        settings.removeAll()
        deviceStore?.clear()
        leds.unpublish()
        super.willForget()
    }

    override func presetDidChange() {
        super.presetDidChange()
        if connected {
            settings.forEach { setting in
                setting.applyPreset()
            }
        }
        leds.notifyUpdated()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureLedsUid:
            ArsdkFeatureLeds.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            arsdkLedDecoder.decode(command)
        default:
            break
        }
    }
}

/// Extension for methods to send Led commands.
extension LedsController {
    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Led_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendLedCommand(.getState(getState))
    }

    /// Sends switch led command.
    ///
    /// - Parameters:
    ///   - type: led type
    ///   - enabled: `true` to enable tof led, `false` otherwise
    /// - Returns: `true` if the command has been sent
    func sendSwitchCommand(type: Arsdk_Led_LedType, enabled: Bool) -> Bool {
        var activateLed = Arsdk_Led_Command.Activate()
        activateLed.ledType = type
        activateLed.enabled = enabled
        return sendLedCommand(.activate(activateLed))
    }

    /// Sends to the drone a Led command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendLedCommand(_ command: Arsdk_Led_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkLedCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension for events processing.
extension LedsController: ArsdkLedEventDecoderListener {
    func onState(_ state: Arsdk_Led_Event.State) {
        ledsSupport = .proto
        if state.hasDefaultCapabilities {
            let standardIsSupported = state.defaultCapabilities.supportedLedTypes.contains(.standard)
            deviceStore?.write(key: SettingKey.stateKey, value: standardIsSupported)
            if standardIsSupported {
                leds.createStandard()
                prepareOfflineSettingStandard()
            }

            let infraredIsSupported = state.defaultCapabilities.supportedLedTypes.contains(.infrared)
            deviceStore?.write(key: SettingKey.infraredKey, value: infraredIsSupported)
            if infraredIsSupported {
                leds.createInfrared()
                prepareOfflineSettingInfrared()
            }

            let tofIsSupported = state.defaultCapabilities.supportedLedTypes.contains(.tof)
            deviceStore?.write(key: SettingKey.tofKey, value: tofIsSupported)
            if tofIsSupported {
                leds.createTof()
                prepareOfflineSettingTof()
            }

            deviceStore?.commit()
        }

        if let standardState = state.activationState.first(where: { $0.ledType == .standard }) {
            standardSetting?.handleNewValue(value: standardState.enabled)
        }

        if let infraredState = state.activationState.first(where: { $0.ledType == .infrared }) {
            infraredSetting?.handleNewValue(value: infraredState.enabled)
        }

        if let tofState = state.activationState.first(where: { $0.ledType == .tof }) {
            tofSetting?.handleNewValue(value: tofState.enabled)
        }
        leds.publish()
    }

    func onLuminosity(_ luminosity: Arsdk_Led_Event.Luminosity) {
        // ignored
    }
}

/// Leds decode callback implementation
extension LedsController: ArsdkFeatureLedsCallback {

    func onIrState(ledState: ArsdkFeatureLedsSwitchState) {
        if ledsSupport == .proto { return }
        switch ledState {
        case .off:
            infraredSetting?.handleNewValue(value: false)
        case .on:
            infraredSetting?.handleNewValue(value: true)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown InfraredLedsState, skipping this event.")
        }
        leds.notifyUpdated()
    }

    func onSwitchState(switchState: ArsdkFeatureLedsSwitchState) {
        if ledsSupport == .proto { return }
        switch switchState {
        case .off:
            standardSetting?.handleNewValue(value: false)
        case .on:
            standardSetting?.handleNewValue(value: true)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown LedsSwitchState, skipping this event.")
        }
        leds.notifyUpdated()
    }

    func onCapabilities(supportedCapabilitiesBitField: UInt) {
        if ledsSupport == .proto { return }
        ledsSupport = supportedCapabilitiesBitField != 0 ? .legacy : .unsupported

        let capabilities = LedsSupportedCapabilities.createSetFrom(bitField: supportedCapabilitiesBitField)

        let ledsStateIsSupported = capabilities.contains(.onOff)
        deviceStore?.write(key: SettingKey.stateKey, value: ledsStateIsSupported)
        if ledsStateIsSupported {
            leds.createStandard()
            prepareOfflineSettingStandard()
        }

        let infraredIsSupported = capabilities.contains(.infrared)
        deviceStore?.write(key: SettingKey.infraredKey, value: infraredIsSupported)
        if infraredIsSupported {
            leds.createInfrared()
            prepareOfflineSettingInfrared()
        }

        deviceStore?.commit()
    }
}

extension LedsSupportedCapabilities: ArsdkMappableEnum {

    /// Create set of led capabilites from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all led capabilites set in bitField
    static func createSetFrom(bitField: UInt) -> Set<LedsSupportedCapabilities> {
        var result = Set<LedsSupportedCapabilities>()
        ArsdkFeatureLedsSupportedCapabilitiesBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let state = LedsSupportedCapabilities(fromArsdk: arsdkValue) {
                result.insert(state)
            }
        }
        return result
    }
    static var arsdkMapper = Mapper<LedsSupportedCapabilities, ArsdkFeatureLedsSupportedCapabilities>([
        .onOff: .onOff,
        .infrared: .infrared])
}
