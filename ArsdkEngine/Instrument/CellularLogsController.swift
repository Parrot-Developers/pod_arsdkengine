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

/// Log messages queue.
class LogsQueue {

    /// Log messages.
    var messages: [String] = []

    /// Maximum total number of characters in log messages.
    private let maxSize: UInt

    /// Total number of characters in log messages.
    private var size: Int {
        messages.reduce(0) { $0 + $1.count }
    }

    /// Constructor.
    ///
    /// - Parameter maxSize: maximum total number of characters in log messages
    init(maxSize: UInt) {
        self.maxSize = maxSize
    }

    /// Adds a log message to messages queue.
    ///
    /// - Parameter message: log message to add
    func append(message: String) {
        messages.append(message)
        // remove first messages, if necessary, to limit size
        while messages.count > 1 && size > maxSize {
            messages.removeFirst()
        }
        // limit latest message size, if necessary
        if messages.count == 1 && size > maxSize {
            messages[0] = String(messages[0].prefix(Int(maxSize)))
        }
    }

    /// Clears log messages.
    func clear() {
        messages = []
    }
}

/// CellularLogs component controller.
class CellularLogsController: DeviceComponentController {

    /// Cellular logs component.
    private var cellularLogs: CellularLogsCore!

    /// Decoder for cellular logs events.
    private var arsdkDecoder: ArsdkNetdebuglogEventDecoder!

    /// Log messages related to cellular network.
    ///
    /// It is assumed that characters in log messages are mainly ascii symbols, encoded on 1 byte.
    /// So maximum size in bytes is roughtly maximum number of characters.
    private var logs = LogsQueue(maxSize: 1024 * (GroundSdkConfig.sharedInstance.cellularCellularLogsKb ?? 128))

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        cellularLogs = CellularLogsCore(store: deviceController.device.instrumentStore)
        arsdkDecoder = ArsdkNetdebuglogEventDecoder(listener: self)
    }

    /// Device is connected.
    override func didConnect() {
        cellularLogs.update(messages: logs.messages)
            .publish()
    }

    /// Device is disconnected.
    override func didDisconnect() {
        cellularLogs.unpublish()
        logs.clear()
        cellularLogs.update(messages: logs.messages)
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }

}

/// Extension for events processing.
extension CellularLogsController: ArsdkNetdebuglogEventDecoderListener {
    func onLog(_ log: Arsdk_Netdebuglog_Event.Log) {
        guard log.serial == deviceController.device.uid else {
            return
        }
        logs.append(message: log.msg)
        cellularLogs.update(messages: logs.messages)
            .notifyUpdated()
    }
}
