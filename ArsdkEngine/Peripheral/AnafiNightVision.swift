// Copyright (C) 2025 Parrot Drones SAS
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

/// Controller for night vision peripheral
class AnafiNightVision: DeviceComponentController {

    /// Night vision component
    private(set) var nightVision: NightVisionCore!

    /// Decoder for night vision events.
    private var arsdkNightVisionDecoder: ArsdkNightvisionEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkNightVisionDecoder = ArsdkNightvisionEventDecoder(listener: self)
        nightVision = NightVisionCore(store: deviceController.device.peripheralStore, backend: self)
    }

    override func willConnect() {
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        nightVision.destroyModule()
        nightVision.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            arsdkNightVisionDecoder.decode(command)
        }
    }
}

/// Extension for methods to send night vision command.
extension AnafiNightVision: NightVisionBackend {

    /// Activates or deactivates the night vision module.
    ///
    /// - Parameters:
    ///    - value: `true` to activate the night vision module, `false` to deactivate.
    ///    - productId:  the product id
    /// - Returns: `true` if the command has been sent.
    func activate(value: Bool, productId: String) -> Bool {
        var activate = Arsdk_Nightvision_Command.Activate()
        activate.value = value
        activate.productID = productId
        return sendNightVisionCommand(.activate(activate))
    }

    /// Sends to the drone a night vision command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendNightVisionCommand(_ command: Arsdk_Nightvision_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkNightvisionCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends "get state" command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var command = Arsdk_Nightvision_Command.GetState()
        command.includeDefaultCapabilities = true
        return sendNightVisionCommand(.getState(command))
    }
}

/// Night vision decode callback implementation.
extension AnafiNightVision: ArsdkNightvisionEventDecoderListener {
    func onState(_ state: Arsdk_Nightvision_Event.State) {
        if state.hasModule {
            if state.module.hasInfo {
                nightVision.update(productId: state.module.info.productID, version: state.module.info.version)
            }
            if state.module.hasIsActivated {
                nightVision.update(active: state.module.isActivated.value)
            }
        } else {
            nightVision.destroyModule()
        }
        nightVision.publish()
    }
}
