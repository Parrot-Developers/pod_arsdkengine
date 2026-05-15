// Copyright (C) 2023 Parrot Drones SAS
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

/// Base controller for pairing peripheral
class SkyControllerPairing: DeviceComponentController, ArsdkDevicemanagerEventDecoderListener {
    /// Pairing component
    private var pairing: PairingCore!

    /// Decoder for device manager events.
    private var arsdkDecoder: ArsdkDevicemanagerEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        pairing = PairingCore(store: deviceController.device.peripheralStore)
        arsdkDecoder = ArsdkDevicemanagerEventDecoder(listener: self)
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        pairing.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        pairing.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        arsdkDecoder.decode(command)
    }
}

extension SkyControllerPairing {
    func onState(_ state: Arsdk_Devicemanager_Event.State) {
        // ignored
    }

    func onConnectionFailure(_ connectionFailure: Arsdk_Devicemanager_Event.ConnectionFailure) {
        // ignored
    }

    func onDiscoveredDevices(_ discoveredDevices: Arsdk_Devicemanager_Event.DiscoveredDevices) {
        // ignored
    }

    func onPairingFailed(_ pairingFailed: Arsdk_Devicemanager_Event.PairingFailed) {
        pairing.update(failureReason: PairingFailureReason(fromArsdk: pairingFailed.reason)).notifyUpdated()
        pairing.update(failureReason: nil).notifyUpdated()
    }

    func onPairingDone(_ pairingDone: Arsdk_Devicemanager_Event.PairingDone) {
        guard case .drone(let droneModel)? = DeviceModel.from(
            internalId: Int(pairingDone.pairedDevice.info.model)) else { return }

        let pairedDevice = PairedDevice(uid: pairingDone.pairedDevice.info.uid, droneModel: droneModel)
        pairing.update(pairedDevice: pairedDevice).notifyUpdated()
        pairing.update(pairedDevice: nil).notifyUpdated()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension PairingFailureReason: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<PairingFailureReason, Arsdk_Devicemanager_PairingFailureReason>([
        .radioNotReady: .radioNotReady,
        .noRemoteAntenna: .noRemoteAntenna
    ])
}
