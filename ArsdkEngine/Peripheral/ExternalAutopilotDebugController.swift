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
import SwiftProtobuf

/// Base controller for external autopilot debug peripheral
class ExternalAutopilotDebugController: DeviceComponentController {

    /// External autopilot debug component
    private(set) var externalAutopilotDebug: ExternalAutopilotDebugCore!

    /// Decoder for external autopilot events.
    public var arsdkExternalautopilotDecoder: ArsdkExternalautopilotEventDecoder!

    /// Current log messages list received from the drone.
    private var logMessages = [ExternalAutopilotDebugMessage]()

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkExternalautopilotDecoder = ArsdkExternalautopilotEventDecoder(listener: self)
        externalAutopilotDebug = ExternalAutopilotDebugCore(store: deviceController.device.peripheralStore)
    }

    /// Drone is disconnected
    override func didDisconnect() {
        logMessages.removeAll()
        externalAutopilotDebug.update(debugMessages: logMessages)
            .update(flightMode: nil)
        externalAutopilotDebug.unpublish()
    }

    /// Drone will connect
    override func willConnect() {
        _ = sendGetExternalautopilotStateCommand()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            arsdkExternalautopilotDecoder.decode(command)
        }
    }

    /// Sends get external autopilot state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetExternalautopilotStateCommand() -> Bool {
        var getState = Arsdk_Externalautopilot_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendExternalAutoPilotCommand(.getState(getState))
    }

    /// Sends to the device a external auto pilot command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendExternalAutoPilotCommand(_ command: Arsdk_Externalautopilot_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkExternalautopilotCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// External autopilot callback implementation
extension ExternalAutopilotDebugController: ArsdkExternalautopilotEventDecoderListener {
    func onLog(_ log: Arsdk_Externalautopilot_Event.Log) {
        guard let level = ExternalAutopilotDebugMessageLevel(fromArsdk: log.level),
              let source = ExternalAutopilotDebugMessageSource(fromArsdk: log.source) else { return }
        logMessages.append(ExternalAutopilotDebugMessage(level: level, source: source, message: log.msg))
        externalAutopilotDebug.update(debugMessages: logMessages).publish()
    }

    func onState(_ state: Arsdk_Externalautopilot_Event.State) {
        externalAutopilotDebug.update(flightMode: ExternalFlightMode(fromArsdk: state.flightMode))
            .publish()
    }

    func onCapabilities(_ capabilities: Arsdk_Externalautopilot_Event.Capabilities) {
        // nothing to do
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension ExternalAutopilotDebugMessageLevel: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<ExternalAutopilotDebugMessageLevel, Arsdk_Externalautopilot_LogLevel>(
        [.info: .info,
         .warning: .warning,
         .error: .error
        ])
}

/// Extension that adds conversion from/to arsdk enum.
extension ExternalAutopilotDebugMessageSource: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<ExternalAutopilotDebugMessageSource, Arsdk_Externalautopilot_LogSource>(
        [.autopilot: .autopilot,
         .configuration: .configuration
        ])
}

/// Extension that adds conversion from/to arsdk enum.
extension ExternalFlightMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<ExternalFlightMode, Arsdk_Externalautopilot_AutopilotFlightMode>([
        .unknown: .unknown,
        .stabilize: .stabilize,
        .takeOff: .takeoff,
        .guided: .guided,
        .loiter: .loiter,
        .manualCopter: .manual,
        .manualPlane: .manualPlane,
        .mission: .mission,
        .rth: .rth,
        .landing: .landing
    ])
}
