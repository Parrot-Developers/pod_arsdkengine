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

/// WebSocket API notifying changes of flight log store content
class FlightLogWsApi {

    /// Drone server
    private let server: DeviceServer

    /// Closure called when the list of available flight logs changes.
    /// - Note: the drone will only trigger this event once after landing, when it is ready to serve collected flight
    ///         logs after its own internal cleanup.
    private let contentDidChange: () -> Void

    /// Active websocket session
    private var webSocketSession: WebSocketSession?

    /// Notification API
    private let api = "/api/v1/fdr/fdr-lite/notifications"

    /// Constructor
    ///
    /// - Parameters:
    ///   - server: the drone server from which records should be accessed
    ///   - eventCb: callback called when flight logs store content has changed
    init(server: DeviceServer, eventCb: @escaping () -> Void) {
        self.server = server
        self.contentDidChange = eventCb
        startSession()
    }

    /// Starts the websocket session
    private func startSession() {
        webSocketSession = server.newWebSocketSession(api: api, delegate: self)
    }

    /// Notification event
    private struct Event: Decodable {

        /// Event type
        enum EventType: String, Decodable {
            /// New flight log available
            case liteRecordAdded = "lite_record_added"
        }
        /// Event name
        let name: EventType
    }
}

extension FlightLogWsApi: WebSocketSessionDelegate {

    func webSocketSessionDidReceiveMessage(_ data: Data) {
        // decode message
        do {
            let event = try JSONDecoder().decode(Event.self, from: data)
            switch event.name {
            case .liteRecordAdded:
                ULog.d(.flightLogTag, "Received lite_record_added notification")
                contentDidChange()
            }
        } catch let error {
            ULog.w(.flightLogTag, "Failed to decode data: \(error.localizedDescription)")
        }
    }

    func webSocketSessionDidDisconnect() {
        // Unexpected disconnect, or connection could not be established, resetting session
        webSocketSession = nil
    }

    func webSocketSessionConnectionHasError() {
        // An error occurred, ignoring
    }
}
