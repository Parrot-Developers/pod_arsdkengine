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

/// Implementation of `RemoteDeviceManager` for SkyController5 devices.
class SkyController5DroneManager: RemoteDeviceManager {

    /// Decoder for device manager events.
    private var arsdkDecoder: ArsdkDevicemanagerEventDecoder!

    /// Microhard power range (dB).
    private var microhardSupportedPower: ClosedRange<Int> = 0...0

    /// Temporary store for received known providers. Indexed by device uid.
    private var knownProviders: [String: ProviderInfo] = [:]

    /// Constructor.
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkDevicemanagerEventDecoder(listener: self)
    }

    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        arsdkDecoder.decode(command)
    }

    override func connectDevice(uid: String, technology: DeviceConnectorTechnology,
                                parameters: [DeviceConnectionParameter], wakeIdle: Bool) -> Bool {
        ULog.d(.ctrlTag, "SkyController5DroneManager: sending connect command, \(uid)")
        switch technology {
        case .microhard:
            var power: Int?
            for parameter in parameters {
                if case let .operationPower(operationPower) = parameter {
                    power = operationPower
                }
            }
            return sendConnectMicohardCommand(deviceUid: uid, power: power, wakeIdle: wakeIdle)
        case .wifi:
            var password: String?
            for parameter in parameters {
                if case let .securityKey(key) = parameter {
                    password = key
                }
            }
            return sendConnectWifiCommand(deviceUid: uid, password: password, wakeIdle: wakeIdle)
        case .mars:
            return sendConnectMarsCommand(deviceUid: uid, wakeIdle: wakeIdle)
        default:
            return false
        }
    }

    override func forgetDevice(uid: String) {
        ULog.d(.ctrlTag, "SkyController5DroneManager: sending forget command, \(uid)")
        _ = sendForgetCommand(deviceUid: uid)
    }
}

/// Extension for methods to send DeviceManager commands.
extension SkyController5DroneManager {
    /// Sends to the device a DeviceManager command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(_ command: Arsdk_Devicemanager_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkDevicemanagerCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends command to get device manager state.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Devicemanager_Command.GetState()
        getState.includeDefaultCapabilities = true
        getState.supportsFastConnection = true
        return sendCommand(.getState(getState))
    }

    /// Sends command to connect a device via Wifi.
    ///
    /// - Parameters:
    ///    - deviceUid: device unique identifier
    ///    - password: security key
    ///    - wakeIdle: `true` to wake up the drone if it's in idle state
    /// - Returns: `true` if the command has been sent
    func sendConnectWifiCommand(deviceUid: String, password: String?, wakeIdle: Bool) -> Bool {
        var connect = Arsdk_Devicemanager_Command.ConnectDevice()
        var wifi = Arsdk_Devicemanager_Command.ConnectDevice.Wifi()
        if let password = password {
            wifi.securityKey = password
        }
        connect.wifi = wifi
        connect.uid = deviceUid
        connect.wakeIdle = wakeIdle
        return sendCommand(.connectDevice(connect))
    }

    /// Sends command to connect a device via Microhard.
    ///
    /// - Parameters:
    ///    - deviceUid: device unique identifier
    ///    - power: operation power to use (dB), `nil` for default
    ///    - wakeIdle: `true` to wake up the drone if it's in idle state
    /// - Returns: `true` if the command has been sent
    func sendConnectMicohardCommand(deviceUid: String, power: Int?, wakeIdle: Bool) -> Bool {
        var connect = Arsdk_Devicemanager_Command.ConnectDevice()
        var microhard = Arsdk_Devicemanager_Command.ConnectDevice.Microhard()
        if let power = power {
            microhard.power = Google_Protobuf_UInt32Value(UInt32(power))
        }
        connect.microhard = microhard
        connect.uid = deviceUid
        connect.wakeIdle = wakeIdle
        return sendCommand(.connectDevice(connect))
    }

    /// Sends command to connect a device via Mars.
    ///
    /// - Parameters:
    ///    - deviceUid: device unique identifier
    ///    - wakeIdle: `true` to wake up the drone if it's in idle state
    /// - Returns: `true` if the command has been sent
    func sendConnectMarsCommand(deviceUid: String, wakeIdle: Bool) -> Bool {
        var connect = Arsdk_Devicemanager_Command.ConnectDevice()
        let mars = Arsdk_Devicemanager_Command.ConnectDevice.Mars()
        connect.mars = mars
        connect.uid = deviceUid
        connect.wakeIdle = wakeIdle
        return sendCommand(.connectDevice(connect))
    }

    /// Sends command to forget a device.
    ///
    /// - Parameter deviceUid: device unique identifier
    /// - Returns: `true` if the command has been sent
    func sendForgetCommand(deviceUid: String) -> Bool {
        var forget = Arsdk_Devicemanager_Command.ForgetDevice()
        forget.uid = deviceUid
        return sendCommand(.forgetDevice(forget))
    }
}

/// Extension for events processing.
extension SkyController5DroneManager: ArsdkDevicemanagerEventDecoderListener {
    func onState(_ state: Arsdk_Devicemanager_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            let capabilities = state.defaultCapabilities
            microhardSupportedPower = Int(capabilities.microhard.powerMin)...Int(capabilities.microhard.powerMax)
        }

        // connection state
        switch state.connectionState {
        case .idle, .searching:
            providerWillDisconnect()
        case .connecting(let connecting):
            if let technology = connecting.transport.gsdk {
                let info = ProviderInfo(deviceUid: connecting.device.uid,
                                        deviceModelId: Int(connecting.device.model),
                                        deviceName: connecting.device.networkID,
                                        technology: technology)

                providerWillConnect(info, backupLink: connecting.backupLink == .active)
                if connecting.sdkReady {
                    providerDidConnect(info)
                }
            }
        case .connected(let connected):
            if let technology = connected.transport.gsdk {
                let info = ProviderInfo(deviceUid: connected.device.uid,
                                        deviceModelId: Int(connected.device.model),
                                        deviceName: connected.device.networkID,
                                        technology: technology)
                providerDidConnect(info, backupLink: connected.backupLink == .active)
            }
        case .disconnecting(let disconnecting):
            if let technology = disconnecting.transport.gsdk {
                let id = ProviderId(deviceUid: disconnecting.device.uid,
                                    technology: technology)
                providerWillDisconnect(id)
            }
        case .none:
            break
        }

        // known providers
        if state.hasKnownDevices {
            knownProvidersDidChange(state.knownDevices.devices.flatMap { $0.gsdk })
        }
    }

    func onConnectionFailure(_ connectionFailure: Arsdk_Devicemanager_Event.ConnectionFailure) {
        if let technology = connectionFailure.transport.gsdk,
           connectionFailure.reason == .authenticationFailed ||
            connectionFailure.reason == .radioNotReady {
            let id = ProviderId(deviceUid: connectionFailure.device.uid, technology: technology)
            let cause: DeviceState.ConnectionStateCause = connectionFailure.reason == .authenticationFailed
            ? .badPassword : .radioNotReady
            providerAuthenticationDidFail(id, cause: cause)
        }
    }

    func onDiscoveredDevices(_ discoveredDevices: Arsdk_Devicemanager_Event.DiscoveredDevices) {
        // ignored
    }

    func onPairingDone(_ pairingDone: Arsdk_Devicemanager_Event.PairingDone) {
        // ignored
    }

    func onPairingFailed(_ pairingFailed: Arsdk_Devicemanager_Event.PairingFailed) {
        // ignored
    }
}

/// Extension that adds conversion to `DeviceConnectorTechnology`.
extension Arsdk_Devicemanager_Transport {
    var gsdk: DeviceConnectorTechnology? {
        switch self {
        case .microhard: return .microhard
        case .wifi: return .wifi
        case .mars: return .mars
        default: return nil
        }
    }

    var gsdkConnectionType: DroneConnectionType? {
        switch self {
        case .microhard: return .microhard
        case .wifi: return .wifi
        case .mars: return .mars
        case .cellular: return .cellular
        case .UNRECOGNIZED(_):
            return nil
        }
    }

}

/// Extension that adds conversion to `RemoteDeviceManager.ProviderInfo`.
extension Arsdk_Devicemanager_DeviceInfo {
    func gsdk(technology: DeviceConnectorTechnology) -> RemoteDeviceManager.ProviderInfo {
        RemoteDeviceManager.ProviderInfo(deviceUid: uid, deviceModelId: Int(model),
                                         deviceName: networkID, technology: technology)
    }
}

/// Extension that adds conversion to `[RemoteDeviceManager.ProviderInfo]`.
extension Arsdk_Devicemanager_KnownDevice {
    fileprivate var gsdk: [RemoteDeviceManager.ProviderInfo] {
        var providers: [RemoteDeviceManager.ProviderInfo] = []
        if hasMicrohard && hasInfo {
            providers.append(info.gsdk(technology: .microhard))
        }
        if hasWifi && hasInfo {
            providers.append(info.gsdk(technology: .wifi))
        }
        if hasMars && hasInfo {
            providers.append(info.gsdk(technology: .mars))
        }
        return providers
    }
}
