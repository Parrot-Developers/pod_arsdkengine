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

/// RadioControl peripheral controller for remote controls based on SkyController messages.
class SkyControllerRadioControl: DeviceComponentController, RadioControlBackend {

    /// Component settings key
    private static let settingKey = "RadioControl"

    /// RadioControl component
    private(set) var radioControl: RadioControlCore!

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this peripheral
    private var presetStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case transportKey = "transport"
    }

    /// Stored settings
    enum Setting: Hashable {
        case transport(LinkTransport)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .transport: return .transportKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [.transport(.wifi)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case transport(Set<LinkTransport>)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [.transport([])]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .transport: return .transportKey
            }
        }
    }

    /// Setting values as received from the remote control
    private var rcSettings = Set<Setting>()

    /// `true` when the device has sent transport capabilities during connection phase
    private var transportCapabilitiesReceived = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: SkyControllerRadioControl.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: SkyControllerRadioControl.settingKey)
        }

        super.init(deviceController: deviceController)
        radioControl = RadioControlCore(store: deviceController.device.peripheralStore, backend: self)

        loadPresets()
        if isPersisted {
            radioControl.publish()
        }
    }

    /// Remote control is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        radioControl.unpublish()
        super.willForget()
    }

    /// Remote control is about to connect
    override func willConnect() {
        transportCapabilitiesReceived = false
        rcSettings.removeAll()
        super.willConnect()
    }

    /// Remote control is connected
    override func didConnect() {
        if !transportCapabilitiesReceived {
            // in case the device does not support transport selection, hence does not trigger any transport
            // capabilities callback, mock as if it announced support for WIFI transport only
            capabilitiesDidChange(.transport([.wifi]))
            radioControl.notifyUpdated()
        }
        applyPresets()
        radioControl.publish()
        super.didConnect()
    }

    /// Remote control is disconnected
    override func didDisconnect() {
        super.didDisconnect()

        radioControl.cancelSettingsRollback()

        if isPersisted {
            radioControl.notifyUpdated()
        } else {
            radioControl.unpublish()
        }
    }

    /// Set the transport used between the remote control and the drone
    func set(transport: LinkTransport) -> Bool {
        presetStore?.write(key: SettingKey.transportKey, value: transport).commit()
        if connected {
            return sendTransportCommand(transport)
        } else {
            radioControl.update(transport: transport).notifyUpdated()
            return false
        }
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: SkyControllerRadioControl.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            for setting in Setting.allCases {
                switch setting {
                case .transport:
                    if let supportedTransportsValues: StorableArray<LinkTransport> = deviceStore.read(key: setting.key),
                       let transport: LinkTransport = presetStore.read(key: setting.key) {
                        let supportedTransports = Set(supportedTransportsValues.storableValue)
                        if supportedTransports.contains(transport) {
                            radioControl.update(supportedTransports: supportedTransports).update(transport: transport)
                        }
                    }
                    if let value: LinkTransport = presetStore.read(key: setting.key) {
                        radioControl.update(transport: value)
                    }
                }
                radioControl.notifyUpdated()
            }
        }
    }

    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in rcSettings {
            switch setting {
            case .transport(let transport):
                if let preset: LinkTransport = presetStore?.read(key: setting.key) {
                    if preset != transport {
                        _ = sendTransportCommand(preset)
                    }
                    radioControl.update(transport: preset).notifyUpdated()
                } else {
                    radioControl.update(transport: transport).notifyUpdated()
                }
            }
        }
    }

    /// Send transport command.
    ///
    /// - Parameter transport: requested transport
    /// - Returns: true if the command has been sent
    func sendTransportCommand(_ transport: LinkTransport) -> Bool {
        switch transport {
        case .wifi:
            return sendCommand(ArsdkFeatureRcTransport.setTransportEncoder(transport: .wifi))
        case .radio:
            return sendCommand(ArsdkFeatureRcTransport.setTransportEncoder(transport: .microhard))
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        rcSettings.insert(setting)
        switch setting {
        case .transport(let transport):
            radioControl.update(transport: transport)
        }
        radioControl.notifyUpdated()
    }

    /// Process capabilities changes
    ///
    /// Update radio control and device store. Caller must call `RadioControl.notifyUpdated()` to notify change.
    ///
    /// - Parameter capabilities: changed capabilities
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .transport(let transports):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(transports)))
            radioControl.update(supportedTransports: transports)
        }
        deviceStore?.commit()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureRcTransportUid {
            ArsdkFeatureRcTransport.decode(command, callback: self)
        }
    }
}

extension SkyControllerRadioControl: ArsdkFeatureRcTransportCallback {
    func onTransport(transport: ArsdkFeatureRcTransportTransportLayer) {
        switch transport {
        case .wifi:
            settingDidChange(.transport(.wifi))
        case .microhard:
            settingDidChange(.transport(.radio))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change the transport
            ULog.w(.tag, "Unknown transport, skipping this event.")
        }
    }

    func onCapabilities(transportsBitField: UInt) {
        transportCapabilitiesReceived = true
        var availableTransports: Set<LinkTransport> = []
        if ArsdkFeatureRcTransportTransportLayerBitField.isSet(.wifi, inBitField: transportsBitField) {
            availableTransports.insert(.wifi)
        }
        if ArsdkFeatureRcTransportTransportLayerBitField.isSet(.microhard, inBitField: transportsBitField) {
            availableTransports.insert(.radio)
        }
        capabilitiesDidChange(.transport(availableTransports))
        radioControl.notifyUpdated()
    }
}

extension LinkTransport: StorableEnum {
    static var storableMapper = Mapper<LinkTransport, String>([
        .wifi: "wifi",
        .radio: "radio"])
}
