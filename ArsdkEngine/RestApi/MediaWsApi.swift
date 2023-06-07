// Copyright (C) 2019 Parrot Drones SAS
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

/// WebSocket API notifying changes of mediastore content
public class MediaWsApi {

    /// Drone server
    private let server: DeviceServer
    /// closure called when the websocket notify changes of media store content
    private let eventOccured: (MediaStoreApiChangeEvent) -> Void
    private let errorOccured: (() -> Void)
    /// Active websocket session
    private var webSocketSession: WebSocketSession?

    /// notification API
    private let api = "/api/v1/media/notifications"

    /// Constructor
    ///
    /// - Parameters:
    ///   - server: the drone server from which medias should be accessed
    ///   - onEvent: callback called when media store content has changed
    ///   - event: the event that occured
    init(server: DeviceServer, onEvent: @escaping (_ event: MediaStoreApiChangeEvent) -> Void,
         onFailure: @escaping (() -> Void)) {
        self.server = server
        self.eventOccured = onEvent
        self.errorOccured = onFailure
        startSession()
    }

    /// Starts the websocket session
    private func startSession() {
        webSocketSession = server.newWebSocketSession(api: api, delegate: self)
    }
}

// MARK: - Notification decoding

public extension MediaWsApi {

    /// Notification event.
    struct Notification: Decodable {
        /// Event type
        enum Name: String, Decodable {
            /// The first resource of a new media has been created
            case mediaCreated = "media_created"
            /// The last resource of a media has been removed
            case mediaRemoved = "media_removed"
            /// A new resource of an existing media has been created
            case resourceCreated = "resource_created"
            /// A resource of a media has been removed, the media still has remaining resource
            case resourceRemoved = "resource_removed"
            /// All media have been removed
            case allMediaRemoved = "all_media_removed"
            /// Media database indexing state has changed
            case indexingStateChanged = "indexing_state_changed"
        }
        enum CodingKeys: String, CodingKey {
            case name = "name"
            case data = "data"
        }
        let name: Name
        let event: MediaStoreApiChangeEvent

        enum MediaIdCodinKeys: String, CodingKey {
            case mediaId = "media_id"
        }

        public init(from decoder: Decoder) throws {
            let topContainer = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try topContainer.decode(Name.self, forKey: .name)
            let nestedContainer = try topContainer.nestedContainer(keyedBy: MediaStoreApiChangeEvent.CodingKeys.self,
                                                                   forKey: .data)
            // depending on the type of the notification the `data` container can contain different
            // types
            switch self.name {
            case .allMediaRemoved:
                self.event = .allMediaRemoved
            case .indexingStateChanged:
                let old = try nestedContainer.decode(MediaStoreApiChangeEvent.IndexingState.self, forKey: .oldState)
                let new = try nestedContainer.decode(MediaStoreApiChangeEvent.IndexingState.self, forKey: .newState)
                self.event = .indexingStateChanged(oldState: old, newState: new)
            case .mediaCreated:
                self.event = .createdMedia(try nestedContainer.decode(MediaRestApi.Media.self,
                                                                      forKey: .media))
            case .mediaRemoved:
                self.event = .removedMedia(mediaId: try nestedContainer.decode(String.self,
                                                                               forKey: .mediaId))
            case .resourceCreated:
                let mediaIdContainer = try nestedContainer.nestedContainer(keyedBy: MediaIdCodinKeys.self,
                                                                           forKey: .resource)
                let mediaId = try mediaIdContainer.decode(String.self, forKey: .mediaId)
                let resource = try nestedContainer.decode(MediaRestApi.MediaResource.self,
                                                          forKey: .resource)
                self.event = .createdResource(resource, mediaId: mediaId)
            case .resourceRemoved:
                self.event = .removedResource(resourceId: try nestedContainer.decode(String.self,
                                                                                     forKey: .resourceId))
            }
        }
    }
}

// MARK: - Web socket delegate

extension MediaWsApi: WebSocketSessionDelegate {

    func webSocketSessionDidReceiveMessage(_ data: Data) {
        ULog.d(.mediaTag, "webSocketSessionDidReceiveMessage received \(String(data: data, encoding: .utf8) ?? "<undecodable data>")")
        // decode message
        do {
            let decoder = JSONDecoder()
            // need to override the way date are parsed because default format is iso8601 extended
            decoder.dateDecodingStrategy = .formatted(.iso8601Base)
            let notification = try decoder.decode(Notification.self, from: data)
            eventOccured(notification.event)
        } catch let error {
            ULog.w(.mediaTag, "Failed to decode data: \(error.localizedDescription)")
        }
    }

    func webSocketSessionDidDisconnect() {
        // Unexpected disconnect, or connection could not be established, retry
        webSocketSession = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            self?.startSession()
            // Trigger the failure
            self?.errorOccured()
        }
    }

    func webSocketSessionConnectionHasError() {
        // An error occurred, ignoring
        ULog.e(.mediaTag, "web socket encountered an error")
    }
}
