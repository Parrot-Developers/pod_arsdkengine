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

/// Kill-switch component controller for Anafi 3 drones.
class Anafi3KillSwitch: DeviceComponentController {
    /// Kill-switch component.
    private var killSwitch: KillSwitchCore!

    /// Decoder for kill-switch events.
    private var arsdkDecoder: ArsdkKillswitchEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)

        arsdkDecoder = ArsdkKillswitchEventDecoder(listener: self)

        killSwitch = KillSwitchCore(store: deviceController.device.peripheralStore, backend: self)
    }

    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        super.didDisconnect()

        killSwitch.cancelSettingsRollback()
            .update(activationSource: nil)

        killSwitch.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Kill-switch backend implementation.
extension Anafi3KillSwitch: KillSwitchBackend {
    func set(mode: KillSwitchMode) -> Bool {
        var sent = false
        if connected,
           let mode = mode.arsdkValue {
            var setMode = Arsdk_Killswitch_Command.SetMode()
            setMode.mode = mode
            sent = sendKillSwitchCommand(.setMode(setMode))
        }
        return sent
    }

    func set(secureMessage: String) -> Bool {
        var sent = false
        if connected {
            var setSecureMessage = Arsdk_Killswitch_Command.SetSecureMessage()
            setSecureMessage.message = secureMessage
            sent = sendKillSwitchCommand(.setSecureMessage(setSecureMessage))
        }
        return sent
    }

    func activate() -> Bool {
        var sent = false
        if connected {
            let activate = Arsdk_Killswitch_Command.Activate()
            sent = sendKillSwitchCommand(.activate(activate))
        }
        return sent
    }
}

/// Extension for methods to send kill-switch commands.
extension Anafi3KillSwitch {
    /// Sends to the drone a kill-switch command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendKillSwitchCommand(_ command: Arsdk_Killswitch_Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = ArsdkKillswitchCommandEncoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Killswitch_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendKillSwitchCommand(.getState(getState))
    }
}

/// Extension for events processing.
extension Anafi3KillSwitch: ArsdkKillswitchEventDecoderListener {
    func onState(_ state: Arsdk_Killswitch_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            let capabilities = state.defaultCapabilities
            let modes = Set(capabilities.supportedModes.compactMap { KillSwitchMode(fromArsdk: $0) })
            killSwitch.update(supportedModes: modes)
        }

        // mode
        if state.hasBehavior, let mode = KillSwitchMode(fromArsdk: state.behavior.mode) {
            killSwitch.update(mode: mode)
        }

        // secure message
        if state.hasSecureMessage {
            killSwitch.update(secureMessage: state.secureMessage.value)
        }

        // activation state
        if let activationState = state.activationState {
            switch activationState {
            case .idle:
                killSwitch.update(activationSource: nil)
            case .activatedBy(let source):
                killSwitch.update(activationSource: KillSwitchActivationSource(fromArsdk: source) ?? .unidentified)
            }
        }

        killSwitch.publish()
        killSwitch.notifyUpdated()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension KillSwitchMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<KillSwitchMode, Arsdk_Killswitch_Mode>([
        .disabled: .disabled,
        .soft: .soft,
        .hard: .hard])
}

/// Extension that adds conversion from/to arsdk enum.
extension KillSwitchActivationSource: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<KillSwitchActivationSource, Arsdk_Killswitch_ActivationSource>([
        .sdk: .sdk,
        .sms: .sms,
        .lora: .lora])
}
