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
import SwiftProtobuf

/// Controller for network control peripheral.
class NetworkController: DeviceComponentController, NetworkControlBackend {

    /// Component settings key.
    private static let settingKey = "NetworkControl"

    /// Network control component.
    private(set) var networkControl: NetworkControlCore!

    /// Store device specific values.
    private let deviceStore: SettingsStore?

    /// Preset store for this component.
    private var presetStore: SettingsStore?

    /// Keys for stored settings and capabilities.
    enum SettingKey: String, StoreKey {
        case routingPolicyKey = "routingPolicy"
        case maxCellularBitrateKey = "maxCellularBitrate"
        case directConnectionModeKey = "directConnectionMode"
    }

    /// Stored settings.
    enum Setting: Hashable {
        case routingPolicy(NetworkControlRoutingPolicy)
        case maxCellularBitrate(Int)
        case directConnectionMode(NetworkDirectConnectionMode)

        /// Setting storage key.
        var key: SettingKey {
            switch self {
            case .routingPolicy: return .routingPolicyKey
            case .maxCellularBitrate: return .maxCellularBitrateKey
            case .directConnectionMode: return .directConnectionModeKey
            }
        }

        /// All values to allow enumerating settings.
        static let allCases: [Setting] = [
            .routingPolicy(.automatic),
            .maxCellularBitrate(0),
            .directConnectionMode(.secure)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings.
    enum Capabilities {
        case routingPolicy(Set<NetworkControlRoutingPolicy>)
        case maxCellularBitrate(Int, Int)
        case directConnectionMode(Set<NetworkDirectConnectionMode>)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [
            .routingPolicy([]),
            .maxCellularBitrate(0, 0),
            .directConnectionMode([])]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .routingPolicy: return .routingPolicyKey
            case .maxCellularBitrate: return .maxCellularBitrateKey
            case .directConnectionMode: return .directConnectionModeKey
            }
        }
    }

    /// Setting values as received from the drone.
    private var droneSettings = Set<Setting>()

    /// Decoder for network events.
    private var arsdkDecoder: ArsdkNetworkEventDecoder!

    /// Whether `State` message with capabilities has been received since `GetState` command was sent.
    private var capabilitiesReceived = false

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: NetworkController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: NetworkController.settingKey)
        }
        super.init(deviceController: deviceController)

        arsdkDecoder = ArsdkNetworkEventDecoder(listener: self)

        networkControl = NetworkControlCore(store: deviceController.device.peripheralStore, backend: self)

        // load settings
        if let deviceStore = deviceStore, let presetStore = presetStore, !deviceStore.new && !presetStore.new {
            loadPresets()
            networkControl.publish()
        }
    }

    /// Drone is about to be forgotten.
    override func willForget() {
        deviceStore?.clear()
        networkControl.unpublish()
        super.willForget()
    }

    /// Drone is about to be connected.
    override func willConnect() {
        super.willConnect()
        // remove settings stored while connecting. We will get new one on the next connection.
        droneSettings.removeAll()
        capabilitiesReceived = false
        _ = sendGetStateCommand()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        super.didDisconnect()

        // clear all non saved values
        networkControl.cancelSettingsRollback()
            .update(link: nil)
            .update(links: [])

        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            networkControl.unpublish()
        } else {
            networkControl.notifyUpdated()
        }
    }

    /// Preset has been changed.
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: NetworkController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Load saved settings.
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            for setting in Setting.allCases {
                switch setting {
                case .routingPolicy:
                    if let policies: StorableArray<NetworkControlRoutingPolicy> = deviceStore.read(key: setting.key),
                        let policy: NetworkControlRoutingPolicy = presetStore.read(key: setting.key) {
                        let supportedPolicies = Set(policies.storableValue)
                        if supportedPolicies.contains(policy) {
                            networkControl.update(supportedPolicies: supportedPolicies)
                                .update(policy: policy)
                        }
                    }
                case .maxCellularBitrate:
                    if let value: Int = presetStore.read(key: setting.key),
                        let range: (min: Int, max: Int) = deviceStore.readRange(key: setting.key) {
                        networkControl.update(maxCellularBitrate: (range.min, value, range.max))
                    }
                case .directConnectionMode:
                    if let modes: StorableArray<NetworkDirectConnectionMode> = deviceStore.read(key: setting.key),
                       let mode: NetworkDirectConnectionMode = presetStore.read(key: setting.key) {
                        let supportedModes = Set(modes.storableValue)
                        if supportedModes.contains(mode) {
                            networkControl.update(supportedDirectConnectionModes: supportedModes)
                                .update(directConnectionMode: mode)
                        }
                    }
                }
            }
            networkControl.notifyUpdated()
        }
    }

    /// Applies presets.
    ///
    /// Iterates settings received during connection.
    private func applyPresets() {
        for setting in droneSettings {
            switch setting {
            case .routingPolicy(let routingPolicy):
                if let preset: NetworkControlRoutingPolicy = presetStore?.read(key: setting.key) {
                    if preset != routingPolicy {
                         _ = sendRoutingPolicyCommand(preset)
                    }
                    networkControl.update(policy: preset).notifyUpdated()
                } else {
                    networkControl.update(policy: routingPolicy).notifyUpdated()
                }
            case .maxCellularBitrate(let value):
                if let preset: Int = presetStore?.read(key: setting.key) {
                    if preset != value {
                        _ = sendMaxCellularBitrate(preset)
                    }
                    networkControl.update(maxCellularBitrate: (min: nil, value: preset, max: nil))
                } else {
                    networkControl.update(maxCellularBitrate: (min: nil, value: value, max: nil))
                }
            case .directConnectionMode(let mode):
                if let preset: NetworkDirectConnectionMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendDirectConnectionCommand(preset)
                    }
                    networkControl.update(directConnectionMode: preset).notifyUpdated()
                } else {
                    networkControl.update(directConnectionMode: mode).notifyUpdated()
                }
            }
        }
    }

    /// Called when a command that notifiies a setting change has been received.
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .routingPolicy(let routingPolicy):
            if connected {
                networkControl.update(policy: routingPolicy)
            }
        case .maxCellularBitrate(let maxCellularBitrate):
            if connected {
                networkControl.update(maxCellularBitrate: (min: nil, value: maxCellularBitrate, max: nil))
            }
        case .directConnectionMode(let mode):
            if connected {
                networkControl.update(directConnectionMode: mode)
            }
        }
        networkControl.notifyUpdated()
    }

    /// Processes stored capabilities changes.
    ///
    /// Update network control and device store.
    ///
    /// - Parameter capabilities: changed capabilities
    /// - Note: Caller must call `networkControl.notifyUpdated()` to notify change.
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .routingPolicy(let routingPolicies):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(routingPolicies)))
            networkControl.update(supportedPolicies: routingPolicies)
        case .maxCellularBitrate(let min, let max):
            deviceStore?.writeRange(key: capabilities.key, min: min, max: max)
            networkControl.update(maxCellularBitrate: (min: min, value: nil, max: max))
        case .directConnectionMode(let modes):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(modes)))
            networkControl.update(supportedDirectConnectionModes: modes)
        }
        deviceStore?.commit()
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }

    /// Sets routing policy.
    ///
    /// - Parameter policy: the new policy
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(policy: NetworkControlRoutingPolicy) -> Bool {
        presetStore?.write(key: SettingKey.routingPolicyKey, value: policy).commit()
        if connected {
            return sendRoutingPolicyCommand(policy)
        } else {
            networkControl.update(policy: policy).notifyUpdated()
            return false
        }
    }

    /// Sets maximum cellular bitrate.
    ///
    /// - Parameter maxCellularBitrate: the new maximum cellular bitrate, in kilobits per second
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxCellularBitrate: Int) -> Bool {
        presetStore?.write(key: SettingKey.maxCellularBitrateKey, value: maxCellularBitrate).commit()
        if connected {
            return sendMaxCellularBitrate(maxCellularBitrate)
        } else {
            networkControl.update(maxCellularBitrate: (min: nil, value: maxCellularBitrate, max: nil))
                .notifyUpdated()
            return false
        }
    }

    /// Sets direct connection mode.
    ///
    /// - Parameter directConnectionMode: the new mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(directConnectionMode: NetworkDirectConnectionMode) -> Bool {
        presetStore?.write(key: SettingKey.directConnectionModeKey, value: directConnectionMode).commit()
        if connected {
            return sendDirectConnectionCommand(directConnectionMode)
        } else {
            networkControl.update(directConnectionMode: directConnectionMode).notifyUpdated()
            return false
        }
    }
}

/// Extension for methods to send Network commands.
extension NetworkController {
    /// Sends to the drone a Network command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendNetworkCommand(_ command: Arsdk_Network_Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = ArsdkNetworkCommandEncoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Network_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendNetworkCommand(.getState(getState))
    }

    /// Sends routing policy command.
    ///
    /// - Parameter policy: requested routing policy
    /// - Returns: `true` if the command has been sent
    func sendRoutingPolicyCommand(_ routingPolicy: NetworkControlRoutingPolicy) -> Bool {
        var sent = false
        if let routingPolicy = routingPolicy.arsdkValue {
            var setRoutingPolicy = Arsdk_Network_Command.SetRoutingPolicy()
            setRoutingPolicy.policy = routingPolicy
            sent = sendNetworkCommand(.setRoutingPolicy(setRoutingPolicy))
        }
        return sent
    }

    /// Sends maximum cellular bitrate command.
    ///
    /// - Parameter maxCellularBitrate: requested maximum cellular bitrate, in kilobytes per second
    /// - Returns: `true` if the command has been sent
    func sendMaxCellularBitrate(_ maxCellularBitrate: Int) -> Bool {
        var setCellularMaxBitrate = Arsdk_Network_Command.SetCellularMaxBitrate()
        setCellularMaxBitrate.maxBitrate = Int32(maxCellularBitrate)
        return sendNetworkCommand(.setCellularMaxBitrate(setCellularMaxBitrate))
    }

    /// Sends direct connection command.
    ///
    /// - Parameter mode: requested mode
    /// - Returns: `true` if the command has been sent
    func sendDirectConnectionCommand(_ mode: NetworkDirectConnectionMode) -> Bool {
        var sent = false
        if let arsdkMode = mode.arsdkValue {
            var setDirectConnection = Arsdk_Network_Command.SetDirectConnection()
            setDirectConnection.mode = arsdkMode
            sent = sendNetworkCommand(.setDirectConnection(setDirectConnection))
        }
        return sent
    }
}

/// Extension for events processing.
extension NetworkController: ArsdkNetworkEventDecoderListener {
    func onState(_ state: Arsdk_Network_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            let capabilities = state.defaultCapabilities
            let minBitrate = Int(capabilities.cellularMinBitrate)
            let maxBitrate = Int(capabilities.cellularMaxBitrate)
            capabilitiesDidChange(.maxCellularBitrate(minBitrate, maxBitrate))
            let supportedModes = Set(capabilities.supportedDirectConnectionModes.compactMap {
                NetworkDirectConnectionMode(fromArsdk: $0)
            })
            capabilitiesDidChange(.directConnectionMode(supportedModes))
        }

        // routing info
        if state.hasRoutingInfo {
            processRoutingInfo(state.routingInfo)
        }

        // links status
        if state.hasLinksStatus {
            processLinksStatus(state.linksStatus)
        }

        // global link quality
        if state.hasGlobalLinkQuality {
            processGlobalLinkQuality(state.globalLinkQuality)
        }

        // cellular maximum bitrate
        if state.hasCellularMaxBitrate {
            processCellularMaxBitrate(state.cellularMaxBitrate)
        }

        // direct connection mode
        if let mode = NetworkDirectConnectionMode(fromArsdk: state.directConnectionMode) {
            settingDidChange(.directConnectionMode(mode))
        }

        if state.hasDefaultCapabilities,
           !capabilitiesReceived {
            capabilitiesReceived = true
            applyPresets()
            networkControl.publish()
        }
        networkControl.notifyUpdated()
    }

    /// Processes a `RoutingInfo` message.
    ///
    /// - Parameter routingInfo: message to process
    func processRoutingInfo(_ routingInfo: Arsdk_Network_RoutingInfo) {
        switch routingInfo.currentLink {
        case .cellular:
            networkControl.update(link: .cellular)
        case .wlan:
            networkControl.update(link: .wlan)
        case .any, .UNRECOGNIZED:
            networkControl.update(link: nil)
        }

        if !capabilitiesReceived { // first receipt of this message
            // assume all routing policies are supported
            capabilitiesDidChange(.routingPolicy(Set(NetworkControlRoutingPolicy.allCases)))
        }

        if let routingPolicy = NetworkControlRoutingPolicy.init(fromArsdk: routingInfo.policy) {
            settingDidChange(.routingPolicy(routingPolicy))
        }
    }

    /// Processes a `LinksStatus` message.
    ///
    /// - Parameter linksStatus: message to process
    func processLinksStatus(_ linksStatus: Arsdk_Network_LinksStatus) {
        let links = linksStatus.links.compactMap { $0.gsdkLinkInfo }
        networkControl.update(links: links)
    }

    /// Processes a `GlobalLinkQuality` message.
    ///
    /// - Parameter globalLinkQuality: message to process
    func processGlobalLinkQuality(_ globalLinkQuality: Arsdk_Network_GlobalLinkQuality) {
        if globalLinkQuality.quality == 0 {
            networkControl.update(quality: nil)
        } else {
            networkControl.update(quality: Int(globalLinkQuality.quality) - 1)
        }
    }

    /// Processes a `CellularMaxBitrate` message.
    ///
    /// - Parameter cellularMaxBitrate: message to process
    func processCellularMaxBitrate(_ cellularMaxBitrate: Arsdk_Network_CellularMaxBitrate) {
        var maxCellularBitrate = Int(cellularMaxBitrate.maxBitrate)
        if maxCellularBitrate == 0 {
            // zero means maximum cellular bitrate is set to its upper range value
            maxCellularBitrate = networkControl.maxCellularBitrate.max
        }
        settingDidChange(.maxCellularBitrate(maxCellularBitrate))
    }
}

/// Extension to make NetworkControlRoutingPolicy storable.
extension NetworkControlRoutingPolicy: StorableEnum {
    static var storableMapper = Mapper<NetworkControlRoutingPolicy, String>([
        .all: "all",
        .cellular: "cellular",
        .wlan: "wlan",
        .automatic: "automatic"])
}

/// Extension to make NetworkDirectConnectionMode storable.
extension NetworkDirectConnectionMode: StorableEnum {
    static var storableMapper = Mapper<NetworkDirectConnectionMode, String>([
        .legacy: "legacy",
        .secure: "secure"])
}

/// Extension that adds conversion from/to arsdk enum.
extension NetworkControlRoutingPolicy: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<NetworkControlRoutingPolicy, Arsdk_Network_RoutingPolicy>([
        .all: .all,
        .cellular: .cellular,
        .wlan: .wlan,
        .automatic: .hybrid])
}

/// Extension that adds conversion from/to arsdk enum.
extension NetworkControlLinkType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<NetworkControlLinkType, Arsdk_Network_LinkType>([
        .cellular: .cellular,
        .wlan: .wlan])
}

/// Extension that adds conversion from/to arsdk enum.
extension NetworkControlLinkStatus: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<NetworkControlLinkStatus, Arsdk_Network_LinkStatus>([
        .down: .down,
        .up: .up,
        .running: .running,
        .ready: .ready,
        .connecting: .connecting,
        .error: .error])
}

/// Extension that adds conversion from/to arsdk enum.
///
/// - Note: NetworkControlLinkError.init(fromArsdk: .none) will return `nil`.
extension NetworkControlLinkError: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<NetworkControlLinkError, Arsdk_Network_LinkError>([
        .authentication: .authentication,
        .communicationLink: .commLink,
        .connect: .connect,
        .dns: .dns,
        .publish: .publish,
        .timeout: .timeout,
        .invite: .invite])
}

/// Extension that adds conversion from/to arsdk enum.
extension NetworkDirectConnectionMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<NetworkDirectConnectionMode, Arsdk_Network_DirectConnectionMode>([
        .legacy: .legacy,
        .secure: .secure])
}

/// Extension that adds conversion to gsdk.
extension Arsdk_Network_LinksStatus.LinkInfo {
    /// Creates a new `NetworkControlLinkInfoCore` from `Arsdk_Network_LinksStatus.LinkInfo`.
    var gsdkLinkInfo: NetworkControlLinkInfoCore? {
        if let type = NetworkControlLinkType.init(fromArsdk: type),
            let status = NetworkControlLinkStatus.init(fromArsdk: status) {
            let gsdkQuality = quality == 0 ? nil : Int(quality) - 1
            let error = NetworkControlLinkError.init(fromArsdk: self.error)
            return NetworkControlLinkInfoCore(type: type, status: status, error: error, quality: gsdkQuality)
        }
        return nil
    }
}
