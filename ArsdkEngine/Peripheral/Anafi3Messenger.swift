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
import SwiftProtobuf

/// Messenger component controller for Anafi 3 drones.
class Anafi3Messenger: DeviceComponentController {
    /// Messenger component.
    private(set) var messenger: MessengerCore!

    /// Decoder for sms events.
    private var arsdkDecoder: ArsdkSmsEventDecoder!

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        arsdkDecoder = ArsdkSmsEventDecoder(listener: self)

        messenger = MessengerCore(store: deviceController.device.peripheralStore, backend: self)
    }

    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        super.didDisconnect()
        messenger.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Messenger backend implementation.
extension Anafi3Messenger: MessengerBackend {
    func sendSms(recipient: String, content: String) -> Bool {
        print("messenger sendSms to: \(recipient)  - \(content)")
        var sent = false
        if connected {
            var sendSms = Arsdk_Sms_Command.SendSms()
            sendSms.recipient = recipient
            sendSms.text = content
            sent = sendSmsCommand(.sendSms(sendSms))
        }
        return sent
    }
}

/// Extension for methods to send sms commands.
extension Anafi3Messenger {
    /// Sends to the drone an sms command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendSmsCommand(_ command: Arsdk_Sms_Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = ArsdkSmsCommandEncoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Sms_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendSmsCommand(.getState(getState))
    }
}

/// Extension for events processing.
extension Anafi3Messenger: ArsdkSmsEventDecoderListener {
    func onState(_ state: Arsdk_Sms_Event.State) {
        if state.hasAvailable {
            if state.available.value {
                messenger.publish()
            } else {
                messenger.unpublish()
            }
        }
    }
}
