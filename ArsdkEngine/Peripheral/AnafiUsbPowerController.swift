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

/// USB-C connector power component controller for Anafi drones.
class AnafiUsbPower: DeviceComponentController {

    /// USB power component.
    private var usbPower: UsbPowerCore!

    /// Decoder for USB power events.
    private var arsdkDecoder: ArsdkUsbpowerEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        arsdkDecoder = ArsdkUsbpowerEventDecoder(listener: self)
        usbPower = UsbPowerCore(store: deviceController.device.peripheralStore, backend: self)
    }

    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        super.didDisconnect()

        usbPower.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// USB power backend implementation.
extension AnafiUsbPower: UsbPowerBackend {
    func enable(type: UsbConnectorType, value: Bool) -> Bool {
        var sent = false
        if connected,
           let type = type.arsdkValue {
            var power = Arsdk_Usbpower_Power()
            power.connectorType = type
            power.enabled = value
            sent = sendUsbPower(.power(power))
        }
        return sent
    }

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Usbpower_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendUsbPower(.getState(getState))
    }

    /// Sends to the drone a USB power command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendUsbPower(_ command: Arsdk_Usbpower_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkUsbpowerCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension for events processing.
extension AnafiUsbPower: ArsdkUsbpowerEventDecoderListener {
    func onState(_ state: Arsdk_Usbpower_Event.State) {
        if state.hasDefaultCapabilities {
            let types = Set(state.defaultCapabilities.supportedTypes.compactMap { UsbConnectorType(fromArsdk: $0) })
            usbPower.update(supportedTypes: types)
        }

        if state.hasUsbPowers {
            usbPower.resetStates()
            for power in state.usbPowers.powers {
                if let type = UsbConnectorType(fromArsdk: power.connectorType) {
                    if usbPower.supportedTypes.contains(type) {
                        usbPower.update(type: type, state: power.enabled)
                    }
                }
            }
        }
        usbPower.publish()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension UsbConnectorType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<UsbConnectorType, Arsdk_Usbpower_ConnectorType>([
        .body: .body,
        .battery: .battery])
}
