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

/// Sleep mode component controller for Anafi 3 drones.
class Anafi3SleepMode: DeviceComponentController {
    /// Sleep mode component.
    private var sleepMode: SleepModeCore!

    /// Decoder for sleep mode events.
    private var arsdkDecoder: ArsdkSleepmodeEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        arsdkDecoder = ArsdkSleepmodeEventDecoder(listener: self)

        sleepMode = SleepModeCore(store: deviceController.device.peripheralStore, backend: self)
    }

    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        super.didDisconnect()

        sleepMode.cancelSettingsRollback()

        sleepMode.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Sleep mode backend implementation.
extension Anafi3SleepMode: SleepModeBackend {
    func set(wakeupMessage: String) -> Bool {
        var sent = false
        if connected {
            var setSecureMessage = Arsdk_Sleepmode_Command.SetSecureMessage()
            setSecureMessage.message = wakeupMessage
            sent = sendSleepModeCommand(.setSecureMessage(setSecureMessage))
        }
        return sent
    }

    func activate() -> Bool {
        var sent = false
        if connected {
            let activate = Arsdk_Sleepmode_Command.Activate()
            sent = sendSleepModeCommand(.activate(activate))
        }
        return sent
    }
}

/// Extension for methods to send sleep mode commands.
extension Anafi3SleepMode {
    /// Sends to the drone a sleep mode command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendSleepModeCommand(_ command: Arsdk_Sleepmode_Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = ArsdkSleepmodeCommandEncoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Sleepmode_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendSleepModeCommand(.getState(getState))
    }
}

/// Extension for events processing.
extension Anafi3SleepMode: ArsdkSleepmodeEventDecoderListener {
    func onState(_ state: Arsdk_Sleepmode_Event.State) {
        // secure message
        if state.hasSecureMessage {
            sleepMode.update(wakeupMessage: state.secureMessage.value)
        }

        sleepMode.publish()
        sleepMode.notifyUpdated()
    }

    func onActivation(_ activation: Arsdk_Sleepmode_Event.Activation) {
        sleepMode.update(activationStatus: SleepModeActivationStatus(fromArsdk: activation.status))
        sleepMode.notifyUpdated()

        sleepMode.update(activationStatus: nil)
        sleepMode.notifyUpdated()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension SleepModeActivationStatus: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<SleepModeActivationStatus, Arsdk_Sleepmode_ActivationStatus>([
        .success: .success,
        .failure: .failure])
}
