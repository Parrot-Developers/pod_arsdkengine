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

/// Antiflicker component controller for Anafi 2 drones.
class Anafi2Antiflicker: AntiflickerController {

    /// Component settings key.
    private static let settingKey = "AntiFlicker"

    /// Decoder for antiflicker events.
    private var arsdkDecoder: ArsdkAntiflickerEventDecoder!

    override var canSendCommand: Bool {
        _canSendCommand
    }

    /// `true` when state has been received, turned to `false` at disconnection.
    private var _canSendCommand = false

    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkAntiflickerEventDecoder(listener: self)
    }

    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    override func didConnect() {
        // Nothing to do
    }

    override func didDisconnect() {
        _canSendCommand = false
        super.didDisconnect()
    }

    /// Sends mode command.
    ///
    /// - Parameters:
    ///   - mode: requested mode.
    /// - Returns: `true if the command has been sent
    override func sendModeCommand(_ mode: AntiflickerMode) -> Bool {
        if mode == .auto && !droneSupportsAutoMode {
            ULog.w(.cameraTag, "Cannot send auto antiflicker mode, drone does not support auto mode")
            return false
        }
        var setMode = Arsdk_Antiflicker_Command.SetMode()
        setMode.mode = Arsdk_Antiflicker_Mode(fromArsdk: mode) ?? .disabled
        return sendAntiflickerCommand(.setMode(setMode))

    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Extension for methods to send Antiflicker commands.
extension Anafi2Antiflicker {

    /// Sends to the device an Antiflicker command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendAntiflickerCommand(_ command: Arsdk_Antiflicker_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkAntiflickerCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends "get state" command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var command = Arsdk_Antiflicker_Command.GetState()
        command.includeDefaultCapabilities = true
        return sendAntiflickerCommand(.getState(command))
    }
}

/// Extension for events processing.
extension Anafi2Antiflicker: ArsdkAntiflickerEventDecoderListener {
    func onState(_ state: Arsdk_Antiflicker_Event.State) {
        if state.hasDefaultCapabilities {
            let supportedModes = Set(state.defaultCapabilities.supportedModes.compactMap {$0.arsdkValue})
            capabilitiesDidChange(.mode(supportedModes))
        }

        var mode: AntiflickerMode = .off
        switch state.mode {
        case .disabled:
            mode = .off
            antiflicker.update(value: .off)
        case .automatic(let frequency):
            mode = .auto
            switch frequency {
            case .frequency50Hz:
                antiflicker.update(value: .value50Hz)
            case .frequency60Hz:
                antiflicker.update(value: .value60Hz)
            case .UNRECOGNIZED:
                return
            }
        case .fixed(let frequency):
            switch frequency {
            case .frequency50Hz:
                antiflicker.update(value: .value50Hz)
                mode = .mode50Hz
            case .frequency60Hz:
                antiflicker.update(value: .value60Hz)
                mode = .mode60Hz
            case .UNRECOGNIZED:
                return
            }
        case .none:
            return
        }

        if !canSendCommand {
            _canSendCommand = true
            droneSettings.insert(.mode(mode))
            applyPresets()
            antiflicker.publish()
        } else {
            if antiflicker.setting.mode == .auto && !droneSupportsAutoMode {
                settingDidChange(.mode(.auto))
            } else {
                settingDidChange(.mode(mode))
            }
        }
        antiflicker.notifyUpdated()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension Arsdk_Antiflicker_Mode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Arsdk_Antiflicker_Mode, AntiflickerMode>([
        .automatic: .auto,
        .mode50Hz: .mode50Hz,
        .mode60Hz: .mode60Hz,
        .disabled: .off])
}
