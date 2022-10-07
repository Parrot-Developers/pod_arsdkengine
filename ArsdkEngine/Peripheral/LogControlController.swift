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

/// Log Control supported capabilities
public enum LogControlSupportedCapabilities: Int, CustomStringConvertible, CaseIterable {

    /// Logs deactivation is supported
    case deactivateLogs

    /// Debug description.
    public var description: String {
        switch self {
        case .deactivateLogs:         return "deactivateLogs"
        }
    }

    /// Comparator
    public static func < (lhs: LogControlSupportedCapabilities,
                          rhs: LogControlSupportedCapabilities) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Base controller for Log Control peripheral
class LogControlController: DeviceComponentController, LogControlBackend {
    /// Command typealias
    typealias Command = Arsdk_Developer_Command
    typealias Event = Arsdk_Developer_Event
    typealias Encoder = ArsdkDeveloperCommandEncoder
    typealias Decoder = ArsdkDeveloperEventDecoder

    /// Log Control component
    private var logControl: LogControlCore!

    /// Decoder for developer events.
    private var arsdkDecoder: Decoder!

    /// Indicates if the drone supports the deactivation of Logs
    private var deactivateLogsIsSupported = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        logControl = LogControlCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = Decoder(listener: self)
    }

    /// Drone is about to be connected.
    override func willConnect() {
        super.willConnect()
        // To avoid sending another GetState command, we piggy-back on the one sent by
        // DebugShellController.

        // Of course, this won't work anymore if DebugShellController is removed, so TODO find a better
        // solution..
    }

    /// Drone is connected
    override func didConnect() {
        logControl.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        logControl.unpublish()
        deactivateLogsIsSupported = false
    }

    /// Drone is about to be forgotten
    override func willForget() {
        logControl.unpublish()
        super.willForget()
    }

    func deactivateLogs() -> Bool {
        if deactivateLogsIsSupported {
            sendCommand(ArsdkFeatureSecurityEdition.deactivateLogsEncoder())
            return true
        }
        return false
    }

    func activateMissionLogs(_ activate: Bool) -> Bool {
        var command = Command.AirSdkLog()
        command.enable = activate
        return sendCommand(.airSdkLog(command))
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSecurityEditionUid {
            ArsdkFeatureSecurityEdition.decode(command, callback: self)
        }
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            arsdkDecoder.decode(command)
        }
    }
}

private extension LogControlController {
    /// Sends to the drone a developer airsdk log command.
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

/// Log Control decode callback implementation
extension LogControlController: ArsdkFeatureSecurityEditionCallback {
    func onCapabilities(supportedCapabilitiesBitField: UInt) {
        deactivateLogsIsSupported = ArsdkFeatureSecurityEditionSupportedCapabilitiesBitField.isSet(
            .deactivateLogs,
            inBitField: supportedCapabilitiesBitField)
        logControl.update(canDeactivateLogs: deactivateLogsIsSupported)
    }

    func onLogStorageState(logStorageState: ArsdkFeatureSecurityEditionLogStorageState) {
        var newLogsEnabled: Bool = true
        switch logStorageState {
        case .disabled:
            newLogsEnabled = false
        case .enabled:
            newLogsEnabled = true
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown logsState, skipping this event.")
            return
        }
        logControl.update(areLogsEnabled: newLogsEnabled).notifyUpdated()
    }
}

extension LogControlController: ArsdkDeveloperEventDecoderListener {

    func onState(_ state: Event.State) {
        if state.hasAirsdklog {
            processAirsdkLog(state.airsdklog)
        }
    }

    private func processAirsdkLog(_ event: Event.AirSdkLog) {
        logControl.update(areMissionLogsEnabled: event.enabled).notifyUpdated()
    }
}

extension LogControlSupportedCapabilities: ArsdkMappableEnum {

    /// Create set of log control capabilites from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all log control capabilites set in bitField
    static func createSetFrom(bitField: UInt) -> Set<LogControlSupportedCapabilities> {
        var result = Set<LogControlSupportedCapabilities>()
        ArsdkFeatureSecurityEditionSupportedCapabilitiesBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let state = LogControlSupportedCapabilities(fromArsdk: arsdkValue) {
                result.insert(state)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<LogControlSupportedCapabilities,
        ArsdkFeatureSecurityEditionSupportedCapabilities>([
        .deactivateLogs: .deactivateLogs])
}
