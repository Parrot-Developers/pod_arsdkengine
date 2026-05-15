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

/// WebSocket API notifying changes of dtedastore content
public class DtedWsApi {

    /// Drone server
    private let server: DeviceServer
    /// closure called when the websocket notify changes of dted store content
    private let eventOccured: (DtedStoreApiChangeEvent) -> Void
    /// Active websocket session
    private var webSocketSession: WebSocketSession?

    /// notification API
    private let api: String

    /// Constructor
    ///
    /// - Parameters:
    ///   - server: the drone server from which dted files should be accessed
    ///   - deviceModel: the device model
    ///   - onEvent: callback called when dted store content has changed
    ///   - event: the event that occured
    init(server: DeviceServer, deviceModel: DeviceModel,
         onEvent: @escaping (_ event: DtedStoreApiChangeEvent) -> Void) {
        switch deviceModel {
        case .drone(let droneModel):
            switch droneModel {
            case .anafi4k, .anafiThermal, .anafi2, .anafiUa, .anafiUsa:
                api = "/api/v1/upload-terrain/notifications"
            default:
                api = "/api/v1/terrain/notifications"
            }
        case .rc:
            api = ""
        }
    
        self.server = server
        self.eventOccured = onEvent
        startSession()
    }

    /// Starts the websocket session
    private func startSession() {
        webSocketSession = server.newWebSocketSession(api: api, delegate: self)
    }
}

// MARK: - Notification decoding

public extension DtedWsApi {

    /// Notification event.
    struct Notification: Decodable {
        /// Event type
        enum Name: String, Decodable {
            /// Terrain has been created
            case terrainCreated = "terrain_created"
            /// Terrain has been removed
            case terrainRemoved = "terrain_removed"
        }

        enum CodingKeys: String, CodingKey {
            case name = "name"
            case data = "data"
        }

        let name: Name
        let event: DtedStoreApiChangeEvent

        public init(from decoder: Decoder) throws {
            let topContainer = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try topContainer.decode(Name.self, forKey: .name)
            let nestedContainer = try topContainer.nestedContainer(keyedBy: DtedStoreApiChangeEvent.CodingKeys.self,
                                                                   forKey: .data)

            switch self.name {
            case .terrainCreated:
                self.event = .terrainAdded(try nestedContainer.decode(DtedRestApi.File.self,
                                                                      forKey: .terrain))
            case .terrainRemoved:
                self.event = .terrainRemoved

            }
        }
    }
}

// MARK: - Web socket delegate

extension DtedWsApi: WebSocketSessionDelegate {

    func webSocketSessionDidReceiveMessage(_ data: Data) {
        ULog.d(.dtedTag,
               "webSocketSessionDidReceiveMessage received"
               + " \(String(data: data, encoding: .utf8) ?? "<undecodable data>")")
        // decode message
        do {
            let decoder = JSONDecoder()
            // need to override the way date are parsed because default format is iso8601 extended
            decoder.dateDecodingStrategy = .formatted(.iso8601Base)
            let notification = try decoder.decode(Notification.self, from: data)
            eventOccured(notification.event)
        } catch let error {
            ULog.w(.dtedTag, "Failed to decode data: \(error.localizedDescription)")
        }
    }

    func webSocketSessionDidDisconnect() {
        // Unexpected disconnect, or connection could not be established, retry
        webSocketSession = nil

    }

    func webSocketSessionConnectionHasError() {
        // An error occurred, ignoring
        ULog.e(.dtedTag, "web socket encountered an error")
    }
}
