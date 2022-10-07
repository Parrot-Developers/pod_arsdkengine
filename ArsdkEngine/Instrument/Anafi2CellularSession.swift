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
import SwiftProtobuf

/// Cellular session component controller for Anafi 2 drones.
class Anafi2CellularSession: DeviceComponentController {

    typealias Command = Arsdk_Network_Command
    typealias Event = Arsdk_Network_Event
    typealias Encoder = ArsdkNetworkCommandEncoder
    typealias Decoder = ArsdkNetworkEventDecoder

    /// Cellular session component.
    private var cellularSession: CellularSessionCore!

    /// Decoder for network events.
    private var arsdkDecoder: Decoder!

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        cellularSession = CellularSessionCore(store: deviceController.device.instrumentStore)
        arsdkDecoder = Decoder(listener: self)
    }

    /// Device is about to be connected.
    override func willConnect() {
        super.willConnect()
        // To avoid sending another GetState command, we piggy-back on the one sent by
        // NetworkController.

        // Of course, this won't work anymore if NetworkController is removed, so TODO find a better
        // solution.
    }

    /// Device is disconnected.
    override func didDisconnect() {
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
extension Anafi2CellularSession {
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
extension Anafi2CellularSession: ArsdkNetworkEventDecoderListener {
    func onState(_ state: Event.State) {
        // links status
        if state.hasLinksStatus {
            processLinksStatus(state.linksStatus)
        }

        cellularSession.publish()
        cellularSession.notifyUpdated()
    }

    /// Processes a `LinksStatus` message.
    ///
    /// - Parameter linksStatus: message to process
    func processLinksStatus(_ linksStatus: Arsdk_Network_LinksStatus) {
        guard let cellularLinkInfo = linksStatus.links.filter({ $0.type == .cellular }).first else {
            cellularSession.update(status: nil)
            return
        }
        cellularSession.update(status: CellularSessionStatus(fromArsdk: cellularLinkInfo.cellularStatus))
    }
}
