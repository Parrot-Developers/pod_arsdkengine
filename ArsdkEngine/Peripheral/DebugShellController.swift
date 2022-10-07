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
import GroundSdk

/// Base controller for debug shell peripheral
class DebugShellController: DeviceComponentController, DebugShellBackend {
    /// Command typealias
    typealias Command = Arsdk_Developer_Command
    typealias Event = Arsdk_Developer_Event
    typealias Encoder = ArsdkDeveloperCommandEncoder
    typealias Decoder = ArsdkDeveloperEventDecoder

    /// DebugShell component
    private var debugShell: DebugShellCore!

    /// Decoder for developer events.
    private var arsdkDecoder: Decoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        debugShell = DebugShellCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = Decoder(listener: self)
    }

    /// Drone is about to be forgotten.
    override func willForget() {
        debugShell.unpublish()
        super.willForget()
    }

    /// Drone is about to be connected.
    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        super.didDisconnect()

        // clear all non saved values
        debugShell.cancelSettingsRollback()
            .update(state: .disabled)
            .unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }

    /// Sets debug shell state
    ///
    /// - Parameter state: the new debug shell state
    /// - Returns: `true` if the command has been sent, `false` if not connected.
    func set(state: DebugShellState) -> Bool {
        switch state {
        case .disabled:
            return sendCommand(.disableShell(Command.DisableShell()))
        case .enabled(publicKey: let key):
            var enableShell = Command.EnableShell()
            enableShell.publicKey = key
            return sendCommand(.enableShell(enableShell))
        }
    }
}

private extension DebugShellController {

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        sendCommand(.getState(Command.GetState()))
    }

    /// Sends to the drone a debug shell command.
    ///
    /// - Parameters:
    ///   - command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(_ command: Command.OneOf_ID) -> Bool {
        if let encoder = Encoder.encoder(command) {
            sendCommand(encoder)
            return true
        }
        return false
    }
}

extension DebugShellController: ArsdkDeveloperEventDecoderListener {

    func onState(_ state: Event.State) {
        if state.hasShell {
            processShell(state.shell)
        }
        debugShell.publish()
        debugShell.notifyUpdated()
    }

    /// Processes a `Shell` message.
    ///
    /// - Parameter shell: message to process
    private func processShell(_ shell: Event.Shell) {
        debugShell.update(state: shell.enabled
                          ? .enabled(publicKey: shell.publicKey)
                          : .disabled)

    }
}
