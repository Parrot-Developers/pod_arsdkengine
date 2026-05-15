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

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

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

    /// Routing policy setting backend
    private var routingPolicySetting: OfflineEnumSetting<NetworkControlRoutingPolicy>!

    /// Direct connection mode setting backend
    private var directConnectionModeSetting: OfflineEnumSetting<NetworkDirectConnectionMode>!

    /// Maximum cellular bitrate setting backend.
    private var maxCellularBitrateSetting: OfflineIntSetting!

    /// All setting backends of this peripheral
    private var settings = [OfflineSetting]()

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

    /// Decoder for network events.
    private var arsdkDecoder: ArsdkNetworkEventDecoder!

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

        prepareOfflineSettings()

        if isPersisted {
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
        settings.forEach { setting in
            setting.resetDeviceValue()
        }

        _ = sendGetStateCommand()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        super.didDisconnect()

        // clear all non saved values
        networkControl.cancelSettingsRollback()
            .update(link: nil)
            .update(links: [])

        if isPersisted {
            networkControl.publish()
        } else {
            networkControl.unpublish()
        }
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        super.backupLinkDidActivate()
        networkControl.unpublish()
    }

    /// Preset has been changed.
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        if connected {
            settings.forEach { setting in
                setting.applyPreset()
            }
        }
        networkControl.notifyUpdated()
    }

    private func prepareOfflineSettings() {
        routingPolicySetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.routingPolicyKey,
            setting: networkControl.routingPolicy as! EnumSettingCore,
            notifyComponent: {
            self.networkControl.notifyUpdated()
            }, markChanged: {
                self.networkControl.markChanged()
            }, sendCommand: { routingPolicy in
            self.sendRoutingPolicyCommand(routingPolicy)
        })

        directConnectionModeSetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.directConnectionModeKey,
            setting: networkControl.directConnection as! EnumSettingCore,
            notifyComponent: {
                self.networkControl.notifyUpdated()
            }, markChanged: {
                self.networkControl.markChanged()
            }, sendCommand: { mode in
                self.sendDirectConnectionCommand(mode)
            })

        maxCellularBitrateSetting = OfflineIntSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.maxCellularBitrateKey,
            setting: networkControl.maxCellularBitrate as! IntSettingCore,
            notifyComponent: {
                self.networkControl.notifyUpdated()
            }, markChanged: {
                self.networkControl.markChanged()
            }, sendCommand: { maxCellularBitrate in
                self.sendMaxCellularBitrate(maxCellularBitrate)
            })

        settings = [routingPolicySetting, directConnectionModeSetting, maxCellularBitrateSetting]
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
        return routingPolicySetting.setValue(value: policy)
    }

    /// Sets maximum cellular bitrate.
    ///
    /// - Parameter maxCellularBitrate: the new maximum cellular bitrate, in kilobits per second
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(maxCellularBitrate: Int) -> Bool {
        return maxCellularBitrateSetting.setValue(value: maxCellularBitrate)
    }

    /// Sets direct connection mode.
    ///
    /// - Parameter directConnectionMode: the new mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(directConnectionMode: NetworkDirectConnectionMode) -> Bool {
        return directConnectionModeSetting.setValue(value: directConnectionMode)
    }
}

/// Extension for methods to send Network commands.
extension NetworkController {
    /// Sends to the drone a Network command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendNetworkCommand(_ command: Arsdk_Network_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkNetworkCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
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
            maxCellularBitrateSetting.handleNewBounds(min: minBitrate, max: maxBitrate)

            let supportedModes = Set(capabilities.supportedDirectConnectionModes.compactMap {
                NetworkDirectConnectionMode(fromArsdk: $0)
            })
            directConnectionModeSetting.handleNewAvailableValues(values: supportedModes)

            // assume all routing policies are supported
            routingPolicySetting.handleNewAvailableValues(values: Set(NetworkControlRoutingPolicy.allCases))
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
            directConnectionModeSetting.handleNewValue(value: mode)
        }

        networkControl.publish()
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
        case .direct:
            networkControl.update(link: .direct)
        case .any, .UNRECOGNIZED:
            networkControl.update(link: nil)
        }

        if let routingPolicy = NetworkControlRoutingPolicy(fromArsdk: routingInfo.policy) {
            routingPolicySetting.handleNewValue(value: routingPolicy)
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
        maxCellularBitrateSetting.handleNewValue(value: maxCellularBitrate)
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
/// - Note: NetworkControlLinkError(fromArsdk: .none) will return `nil`.
extension NetworkControlLinkError: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<NetworkControlLinkError, Arsdk_Network_LinkError>([
        .authentication: .authentication,
        .communicationLink: .commLink,
        .connect: .connect,
        .dns: .dns,
        .publish: .publish,
        .timeout: .timeout,
        .invite: .invite,
        .setup: .setup,
        .peerOffline: .peerOffline,
        .peerMismatch: .peerMismatch])
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
        if let type = NetworkControlLinkType(fromArsdk: type),
           let status = NetworkControlLinkStatus(fromArsdk: status) {
            let gsdkQuality = quality == 0 ? nil : Int(quality) - 1
            let error = NetworkControlLinkError(fromArsdk: self.error)
            return NetworkControlLinkInfoCore(type: type, status: status, error: error, quality: gsdkQuality)
        }
        return nil
    }
}
