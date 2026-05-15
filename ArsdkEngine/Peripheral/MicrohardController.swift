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

/// Controller for microhard peripheral.
class MicrohardController: DeviceComponentController, MicrohardBackend {

    /// Component settings key.
    private static let settingKey = "Microhard"

    /// Microhard component.
    private(set) var microhard: MicrohardCore!

    /// Decoder for microhard events.
    private var arsdkDecoder: ArsdkMicrohardEventDecoder!

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        arsdkDecoder = ArsdkMicrohardEventDecoder(listener: self)

        microhard = MicrohardCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is about to be connected.
    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        super.didDisconnect()
        microhard.unpublish()
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }

    func powerOn() -> Bool {
        sendMicrohardCommand(.powerOn(Arsdk_Microhard_Command.PowerOn()))
    }

    func shutdown() -> Bool {
        sendMicrohardCommand(.shutdown(Arsdk_Microhard_Command.ShutDown()))
    }

    func pairDevice(networkId: String, encryptionKey: String,
                    pairingParameters: MicrohardPairingParameters,
                    connectionParameters: MicrohardConnectionParameters) -> Bool {
        var pairDevice = Arsdk_Microhard_Command.PairDevice()
        pairDevice.networkID = networkId
        pairDevice.encryptionKey = encryptionKey
        pairDevice.pairingParameters = pairingParameters.arsdk
        pairDevice.connectionParameters = connectionParameters.arsdk
        return sendMicrohardCommand(.pairDevice(pairDevice))
    }
}

/// Extension for methods to send Microhard commands.
extension MicrohardController {
    /// Sends to the device a Microhard command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendMicrohardCommand(_ command: Arsdk_Microhard_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkMicrohardCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends "get state" command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        return sendMicrohardCommand(.getState(Arsdk_Microhard_Command.GetState()))
    }
}

/// Extension for events processing.
extension MicrohardController: ArsdkMicrohardEventDecoderListener {
    func onState(_ state: Arsdk_Microhard_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            let capabilities = state.defaultCapabilities
            microhard.update(supportedChannelRange: UInt(capabilities.channelMin)...UInt(capabilities.channelMax))
            microhard.update(supportedPowerRange: UInt(capabilities.powerMin)...UInt(capabilities.powerMax))
            let bandwidths = Set(capabilities.bandwidths.compactMap {MicrohardBandwidth(fromArsdk: $0)})
            microhard.update(supportedBandwidths: bandwidths)
            let encryptions = Set(capabilities.encryptionAlgorithms.compactMap {MicrohardEncryption(fromArsdk: $0)})
            microhard.update(supportedEncryptions: encryptions)
        }

        // state
        switch state.state {
        case .offline:
            microhard.update(state: .offline)
        case .booting:
            microhard.update(state: .booting)
        case .idle:
            microhard.update(state: .idle)
        case .pairing(let pairing):
            var pairingParameters: MicrohardPairingParameters?
            if pairing.hasPairingParameters {
                pairingParameters = pairing.pairingParameters.gsdk
            }
            var connectionParameters: MicrohardConnectionParameters?
            if pairing.hasConnectionParameters {
                connectionParameters = pairing.connectionParameters.gsdk
            }
            microhard.update(state: .pairing(networkId: pairing.networkID,
                                             pairingParameters: pairingParameters,
                                             connectionParameters: connectionParameters))
        case .connecting(let connecting):
            microhard.update(state: .connecting(deviceUid: connecting.deviceUid))
        case .connected(let connected):
            microhard.update(state: .connected(deviceUid: connected.deviceUid))
        case .none:
            break
        }

        microhard.publish()
    }

    func onPairing(_ pairing: Arsdk_Microhard_Event.Pairing) {
        var pairingStatus: MicrohardPairingStatus?
        switch pairing.status {
        case .success(let success):
            pairingStatus = .success(networkId: pairing.networkID, deviceUid: success.deviceUid)
        case .failure(let failure):
            pairingStatus = .failure(networkId: pairing.networkID,
                                     reason: MicrohardPairingFailureReason(fromArsdk: failure.reason)!)
        case .none:
            break
        }
        microhard.update(pairingStatus: pairingStatus).notifyUpdated()
        microhard.update(pairingStatus: nil).notifyUpdated()
    }

    func onHardwareError(_ hardwareError: Arsdk_Microhard_Event.HardwareError) {
        // ignored
    }
}

/// Extension that adds conversion to `Arsdk_Microhard_PairingParameters`.
extension MicrohardPairingParameters {
    var arsdk: Arsdk_Microhard_PairingParameters {
        var parameters = Arsdk_Microhard_PairingParameters()
        parameters.channel = UInt32(channel)
        parameters.power = UInt32(power)
        parameters.bandwidth = bandwidth.arsdkValue!
        parameters.encryptionAlgorithm = encryption.arsdkValue!
        return parameters
    }
}

/// Extension that adds conversion to `Arsdk_Microhard_ConnectionParameters`.
extension MicrohardConnectionParameters {
    var arsdk: Arsdk_Microhard_ConnectionParameters {
        var parameters = Arsdk_Microhard_ConnectionParameters()
        parameters.channel = UInt32(channel)
        parameters.power = UInt32(power)
        parameters.bandwidth = bandwidth.arsdkValue!
        return parameters
    }
}

/// Extension that adds conversion to `MicrohardPairingParameters`.
extension Arsdk_Microhard_PairingParameters {
    var gsdk: MicrohardPairingParameters {
        MicrohardPairingParameters(channel: UInt(channel),
                                   power: UInt(power),
                                   bandwidth: MicrohardBandwidth(fromArsdk: bandwidth)!,
                                   encryption: MicrohardEncryption(fromArsdk: encryptionAlgorithm)!)
    }
}

/// Extension that adds conversion to `MicrohardConnectionParameters`.
extension Arsdk_Microhard_ConnectionParameters {
    var gsdk: MicrohardConnectionParameters {
        MicrohardConnectionParameters(channel: UInt(channel),
                                      power: UInt(power),
                                      bandwidth: MicrohardBandwidth(fromArsdk: bandwidth)!)
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension MicrohardPairingFailureReason: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<MicrohardPairingFailureReason, Arsdk_Microhard_PairingFailureReason>([
        .alreadyPaired: .alreadyPaired,
        .deviceNotReachable: .deviceNotReachable,
        .internalError: .internalError,
        .invalidState: .invalidState])
}

/// Extension that adds conversion from/to arsdk enum.
extension MicrohardBandwidth: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<MicrohardBandwidth, Arsdk_Microhard_Bandwidth>([
        .mHz1: .bandwidth1Mhz,
        .mHz2: .bandwidth2Mhz,
        .mHz4: .bandwidth4Mhz,
        .mHz8: .bandwidth8Mhz])
}

/// Extension that adds conversion from/to arsdk enum.
extension MicrohardEncryption: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<MicrohardEncryption, Arsdk_Microhard_Encryption>([
        .none: .none,
        .aes128: .aes128,
        .aes256: .aes256])
}

/// Extension to make `MicrohardBandwidth` storable.
extension MicrohardBandwidth: StorableEnum {
    static var storableMapper = Mapper<MicrohardBandwidth, String>([
        .mHz1: "mHz1",
        .mHz2: "mHz2",
        .mHz4: "mHz4",
        .mHz8: "mHz8"])
}

/// Extension to make `MicrohardEncryption` storable.
extension MicrohardEncryption: StorableEnum {
    static var storableMapper = Mapper<MicrohardEncryption, String>([
        .none: "none",
        .aes128: "aes128",
        .aes256: "aes256"])
}
