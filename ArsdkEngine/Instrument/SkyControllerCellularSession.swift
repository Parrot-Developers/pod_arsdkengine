// Copyright (C) 2021 Parrot Drones SAS
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

/// Cellular session component controller for SkyController.
class SkyControllerCellularSession: DeviceComponentController {

    typealias Command = Arsdk_Controllernetwork_Command
    typealias Event = Arsdk_Controllernetwork_Event
    typealias Encoder = ArsdkControllernetworkCommandEncoder
    typealias Decoder = ArsdkControllernetworkEventDecoder

    /// Cellular link status component.
    private var cellularLink: CellularLinkCore!
    /// Cellular session component.
    private var cellularSession: CellularSessionCore!

    /// Decoder for controller network events.
    private var arsdkDecoder: Decoder!

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        cellularLink = CellularLinkCore(store: deviceController.device.instrumentStore)
        cellularSession = CellularSessionCore(store: deviceController.device.instrumentStore)
        arsdkDecoder = Decoder(listener: self)
    }

    /// Device is about to be connected.
    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    /// Device is disconnected.
    override func didDisconnect() {
        cellularLink.unpublish()
        cellularLink.update(status: nil)
        cellularSession.unpublish()
        cellularSession.update(status: nil)
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Extension for methods to send controller network commands.
extension SkyControllerCellularSession {
    /// Sends to the device a controller network command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(_ command: Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = Encoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }

    /// Sends command to get state.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        sendCommand(.getState(Command.GetState()))
    }
}

/// Extension for events processing.
extension SkyControllerCellularSession: ArsdkControllernetworkEventDecoderListener {
    func onState(_ state: Event.State) {
        // links status
        if state.hasLinksStatus {
            processLinksStatus(state.linksStatus)
        }

        cellularLink.publish()
        cellularSession.publish()
        cellularLink.notifyUpdated()
        cellularSession.notifyUpdated()
    }

    /// Processes a `LinksStatus` message.
    ///
    /// - Parameter linksStatus: message to process
    func processLinksStatus(_ linksStatus: Arsdk_Network_LinksStatus) {
        guard let cellularLinkInfo = linksStatus.links.filter({ $0.type == .cellular }).first else {
            cellularLink.update(status: nil)
            cellularSession.update(status: nil)
            return
        }
        cellularLink.update(status: cellularLinkInfo.gsdkCellularLinkStatus)
        cellularSession.update(status: CellularSessionStatus(fromArsdk: cellularLinkInfo.cellularStatus))
    }
}

/// Extension that adds conversion from/to arsdk enum.
///
/// - Note: CellularLinkStatusError(fromArsdk: .none) will return `nil`.
extension CellularLinkStatusError: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<CellularLinkStatusError, Arsdk_Network_LinkError>([
        .authentication: .authentication,
        .communicationLink: .commLink,
        .connect: .connect,
        .dns: .dns,
        .publish: .publish,
        .timeout: .timeout,
        .invite: .invite])
}

/// Extension that adds conversion to gsdk.
extension Arsdk_Network_LinksStatus.LinkInfo {
    /// Creates a new `CellularLinkStatus` from `Arsdk_Network_LinksStatus.LinkInfo`.
    var gsdkCellularLinkStatus: CellularLinkStatus? {
        if type == .cellular {
            switch status {
            case .up: return .up
            case .down: return .down
            case .connecting: return .connecting
            case .ready: return .ready
            case .running: return .running
            case .error:
                return .error(error: CellularLinkStatusError(fromArsdk: error))
            case .UNRECOGNIZED:
                return nil
            }
        }
        return nil
    }
}

/// Extension that adds conversion from/to arsdk enum.
///
/// - Note: CellularSessionStatus(fromArsdk: .unknown) will return `nil`.
extension CellularSessionStatus: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<CellularSessionStatus, Arsdk_Network_CellularStatus>([
        .modem(.off): .modemOff,
        .modem(.offline): .modemOffline,
        .modem(.updating): .modemFlashing,
        .modem(.online): .modemOnline,
        .modem(.error): .modemError,
        .sim(.locked): .simLocked,
        .sim(.ready): .simReady,
        .sim(.absent): .simAbsent,
        .sim(.error): .simError,
        .network(.searching): .networkSearching,
        .network(.home): .networkHome,
        .network(.roaming): .networkRoaming,
        .network(.registrationDenied): .networkRegistrationDenied,
        .network(.activationDenied): .networkActivationDenied,
        .server(.waitApcToken): .serverWaitApcToken,
        .server(.connecting): .serverConnecting,
        .server(.connected): .serverConnected,
        .server(.unreachableDns): .serverUnreachableDns,
        .server(.unreachableConnect): .serverUnreachableConnect,
        .server(.unreachableAuth): .serverUnreachableAuth,
        .connection(.offline): .connectionOffline,
        .connection(.connecting): .connectionConnecting,
        .connection(.established): .connectionEstablished,
        .connection(.error): .connectionError,
        .connection(.errorCommLink): .connectionErrorCommLink,
        .connection(.errorTimeout): .connectionErrorTimeout,
        .connection(.errorMismatch): .connectionErrorMismatch
    ])
}
