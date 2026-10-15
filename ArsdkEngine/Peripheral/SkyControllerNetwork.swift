// Copyright (C) 2026 Parrot Drones SAS
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

/// Remote control network component controller for SkyController.
class SkyControllerNetwork: DeviceComponentController {

    /// Remote control network component.
    private var remoteControlNetwork: RemoteControlNetworkCore!

    /// Decoder for controller network events.
    private var arsdkDecoder: ArsdkControllernetworkEventDecoder!

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        remoteControlNetwork = RemoteControlNetworkCore(
            store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = ArsdkControllernetworkEventDecoder(listener: self)
    }

    /// Device is about to be connected.
    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    /// Device is disconnected.
    override func didDisconnect() {
        remoteControlNetwork.cancelSettingsRollback()
        remoteControlNetwork.clearEthernetIpConfig()
        remoteControlNetwork.unpublish()
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Extension for methods to send controller network commands.
extension SkyControllerNetwork {

    /// Sends to the device a controller network command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(_ command: Arsdk_Controllernetwork_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkControllernetworkCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends command to get state.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        sendCommand(.getState(Arsdk_Controllernetwork_Command.GetState()))
    }

    /// Sends ethernet IP configuration command.
    ///
    /// - Parameter config: requested ethernet IP configuration
    /// - Returns: `true` if the command has been sent
    func sendEthernetIpConfig(_ config: IpConfig) -> Bool {
        var msg = Arsdk_Network_Command.SetEthernetIpConfig()
        msg.config = config.arsdk
        return sendCommand(.setEthernetIpConfig(msg))
    }
}

/// Extension for RemoteControlNetworkBackend.
extension SkyControllerNetwork: RemoteControlNetworkBackend {
    func set(ethernetIpConfig: IpConfig) -> Bool {
        return sendEthernetIpConfig(ethernetIpConfig)
    }
}

/// Extension for events processing.
extension SkyControllerNetwork: ArsdkControllernetworkEventDecoderListener {
    func onState(_ state: Arsdk_Controllernetwork_Event.State) {
        if state.hasEthernetIpConfig, let gsdkIpConfig = state.ethernetIpConfig.gsdk {
            remoteControlNetwork.update(ethernetIpConfig: gsdkIpConfig)
        }
        remoteControlNetwork.publish()
    }
}
