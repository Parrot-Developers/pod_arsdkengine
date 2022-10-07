// Copyright (C) 2022 Parrot Drones SAS
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

/// Remote control privacy component controller for SkyController message based remote controls.
class SkyControllerPrivacy: PrivacyController {

    /// Decoder for privacy events.
    private var arsdkDecoder: ArsdkControllerprivacyEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        backend = self
        arsdkDecoder = ArsdkControllerprivacyEventDecoder(listener: self)
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Extension for methods to send Controller Privacy commands.
extension SkyControllerPrivacy: PrivacyControllerBackend {

    func sendCommand(getState: Arsdk_Privacy_Command.GetState) -> Bool {
        sendPrivacyCommand(.getState(getState))
    }

    func sendCommand(setLogMode: Arsdk_Privacy_Command.SetLogMode) -> Bool {
        sendPrivacyCommand(.setLogMode(setLogMode))
    }

    /// Sends to the device a Privacy command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendPrivacyCommand(_ command: Arsdk_Controllerprivacy_Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = ArsdkControllerprivacyCommandEncoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }
}

/// Extension for events processing.
extension SkyControllerPrivacy: ArsdkControllerprivacyEventDecoderListener {

    func onState(_ state: Arsdk_Privacy_Event.State) {
        processState(state)
    }
}
