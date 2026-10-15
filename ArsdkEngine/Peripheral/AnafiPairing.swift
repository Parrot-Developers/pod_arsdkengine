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

/// Base controller for pairing peripheral
class AnafiPairing: DeviceComponentController {
    /// Pairing component
    private var pairing: DronePairingCore!

    /// Decoder for device manager events.
    private var arsdkDecoder: ArsdkPrivacyEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        pairing = DronePairingCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = ArsdkPrivacyEventDecoder(listener: self)
    }

    /// Drone is disconnected
    override func didDisconnect() {
        pairing.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Pairing backend implementation
extension AnafiPairing: PairingBackend {
    func setAuthorization(_ value: PairingAuthorization) -> Bool {
        return setAuthorization(authorization: value)
    }
}

/// Extension for methods to send pairing command.
extension AnafiPairing {

    /// Sets the pairing authirization
    ///
    /// - Parameter authorization: the pairing authorization
    /// - Returns: `true` if the command has been sent.
    func setAuthorization(authorization: PairingAuthorization) -> Bool {
        var pairing = Arsdk_Privacy_Command.AuthorizePairing()
        pairing.value = authorization.arsdkValue!
        return sendPrivacyCommand(.authorizePairing(pairing))
    }

    /// Sends to the drone a privacy command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendPrivacyCommand(_ command: Arsdk_Privacy_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkPrivacyCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

extension AnafiPairing: ArsdkPrivacyEventDecoderListener {
    func onState(_ state: Arsdk_Privacy_Event.State) {
        if state.hasDefaultCapabilities {
            let supportedAuthorizations =  state.defaultCapabilities.supportedAuthorizations.compactMap {
                PairingAuthorization(fromArsdk: $0)
            }
            pairing.update(supportedAuthorizations: Set(supportedAuthorizations))
        }

        if state.hasPairingAuthorization,
           let value = PairingAuthorization(fromArsdk: state.pairingAuthorization.value) {
            pairing.update(authorization: value)
        }
        pairing.publish()
    }
}
