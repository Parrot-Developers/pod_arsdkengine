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

/// 4Mb thumbnail cache
private let kThumbnailCacheSize = 4 * 1024 * 1024

/// The media store api change event that comes from the `MediaStoreApiDelegate`.
enum MediaStoreApiChangeEvent {

    /// The indexing state of the media webserver
    enum IndexingState: String, Decodable {
        /// media are not indexed and no indexing is in progress (media requests will result in
        /// 541 error)
        case notIndexed = "NOT_INDEXED"
        /// media indexing is in progress (media requests will result in 541 error)
        case indexing = "INDEXING"
        /// media are indexed (media requests are possible)
        case indexed = "INDEXED"
    }

    /// The storage of a media
    enum MediaStoreStorageType: String, Decodable {
        /// The removable storage
        case removable = "removable_storage"
        /// The internal storage
        case `internal` = "internal_storage"
    }

    /// The first resource of a new media has been created.
    /// - Parameter media: The media that was created
    case createdMedia(_ media: MediaRestApi.Media)
    /// A new resource of an existing media has been created.
    /// - Parameter resource: The resource that was created
    case createdResource(_ resource: MediaRestApi.MediaResource, mediaId: String)
    /// An existing media has been updated.
    /// - Parameter media: The media that was updated
    case updatedMedia(_ media: MediaRestApi.Media)
    /// The last resource of a media has been removed.
    /// - Parameter mediaId: The id of the media that was removed
    case removedMedia(mediaId: String)
    /// A resource of a media has been removed, the media still has remaining resource
    /// - Parameter resourceId: The id of the resource that was removed
    case removedResource(resourceId: String)
    /// All media have been removed
    case allMediaRemoved
    /// The indexing state has changed.
    /// - Parameters:
    ///   - oldState: the old indexing state
    ///   - newState: the new indexing state
    case indexingStateChanged(oldState: IndexingState, newState: IndexingState)
    /// The storage has been removed.
    case storageRemoved(storage: MediaStoreStorageType)
    /// The websocket has disconnected.
    case webSocketDisconnected

    enum CodingKeys: String, CodingKey {
        case oldState = "old_state"
        case newState = "new_state"
        case resourceId = "resource_id"
        case resource
        case mediaId = "media_id"
        case media
        case storage
    }

    /// The GroundSdk representation of itself.
    var gsdkEvent: MediaStoreChangeEvent {
        switch self {
        case .createdMedia(let media):
            return .createdMedia(MediaItemCore.from(httpMedia: media)!)
        case .createdResource(let resource, mediaId: let mediaId):
            return .createdResource(MediaItemResourceCore.from(httpResource: resource)!, mediaId: mediaId)
        case .updatedMedia(let media):
            return .updatedMedia(MediaItemCore.from(httpMedia: media)!)
        case .removedMedia(mediaId: let mediaId):
            return .removedMedia(mediaId: mediaId)
        case .removedResource(resourceId: let resourceId):
            return .removedResource(resourceId: resourceId)
        case .allMediaRemoved:
            return .allMediaRemoved
        case .indexingStateChanged(oldState: let old, newState: let new):
            let mapper = Mapper<MediaStoreIndexingState, IndexingState>([
                .unavailable: .notIndexed,
                .indexing: .indexing,
                .indexed: .indexed])
            return .indexingStateChanged(oldState: mapper.reverseMap(from: old)!,
                                         newState: mapper.reverseMap(from: new)!)
        case .storageRemoved(let storage):
            let mapper = Mapper<StorageType, MediaStoreStorageType>([
                .removable: .removable,
                .internal: .internal])
            return .storageRemoved(storage: mapper.reverseMap(from: storage)!)
        case .webSocketDisconnected:
            return .webSocketDisconnected
        }
    }
}

/// The media store api delegate callbacks.
protocol MediaStoreApiDelegate: AnyObject {
    /// Invoked when a media store change event occurs.
    ///
    /// - Parameters:
    ///   - event: the event that occurred
    func receivedMediaStoreChangedEvent(_ event: MediaStoreApiChangeEvent)

    /// Invoked when the indexing state changes.
    ///
    /// - Parameters:
    ///   - indexingState: the new indexing state
    func indexingStateChanged(_ indexingState: MediaStoreIndexingState)

    /// Invoked when the different counters get updated.
    ///
    /// - Parameters:
    ///   - videoMediaCount: the new video media count
    ///   - photoMediaCount: the new photo media count
    ///   - videoResourceCount: the new video resource count
    ///   - photoResourceCount: the photo video resource count
    func countersUpdated(videoMediaCount: Int, photoMediaCount: Int,
                         videoResourceCount: Int, photoResourceCount: Int)
}

/// Media store API
protocol MediaStoreApi: AnyObject {

    /// The media store api delegate
    var delegate: MediaStoreApiDelegate? { get set }

    /// Configure the delegate
    func configure()

    /// Reset the delegate
    func reset()

    /// Start watching media store content.
    ///
    /// When content watching is started, backend must call `mediaStore.markContentChanged()`
    /// when the content of the media store changes.
    func startWatchingContentChanges()

    /// Stop watching media store content.
    func stopWatchingContentChanges()

    /// Get the list of the medias on the drone
    ///
    /// - Parameters:
    ///   - completion: closure that will be called when browsing did finish
    ///   - medias: list of the medias available on the device
    /// - Returns: a request that can be canceled
    func browse(completion: @escaping (_ medias: [MediaItemCore]) -> Void) -> CancelableCore?

    /// Get the list of the medias on the drone
    ///
    /// - Parameters:
    ///   - storage: the storage to browse
    ///   - completion: closure that will be called when browsing did finish
    ///   - medias: list of the medias available on the device
    /// - Returns: a request that can be canceled
    func browse(storage: StorageType?,
                completion: @escaping (_ medias: [MediaItemCore]) -> Void) -> CancelableCore?

    /// Download the thumbnail of a given media.
    ///
    /// - Parameters:
    ///   - owner: owner of the thumbnail to fetch
    ///   - completion: closure that will be called when download is done
    ///   - thumbnailData: the data of the thumbnail image
    /// - Returns: a request that can be canceled
    func downloadThumbnail(for owner: MediaStoreThumbnailCacheCore.ThumbnailOwner,
                           completion: @escaping (_ thumbnailData: Data?) -> Void) -> IdentifiableCancelableCore?

    /// Download a resource.
    ///
    /// - Parameters:
    ///   - resource: resource to download
    ///   - type: download type
    ///   - destDirectoryPath: download destination path
    ///   - progress: progress callback
    ///   - progressValue: the progress value, from 0 to 100
    ///   - completion: completion callback
    ///   - fileUrl: the url of the downloaded file. `nil` if an error occurred
    /// - Returns: a request that can be canceled
    func download(resource: MediaItemResourceCore, type: DownloadType, destDirectoryPath: String,
                  progress: @escaping (_ progressValue: Int) -> Void,
                  completion: @escaping (_ fileUrl: URL?) -> Void) -> CancelableCore?

    /// Download a resource signature.
    ///
    /// - Parameters:
    ///   - resource: resource for which to download signature
    ///   - destDirectoryPath: download destination path
    ///   - completion: completion callback
    ///   - signatureUrl: the url of the downloaded signature. `nil` if an error occurred
    /// - Returns: a request that can be canceled
    func downloadSignature(resource: MediaItemResourceCore, destDirectoryPath: String,
                           completion: @escaping (_ signatureUrl: URL?) -> Void) -> CancelableCore?

    /// Uploads a resource.
    ///
    /// - Parameters:
    ///   - resourceUrl: the resource file to upload
    ///   - target: target media item to attach uploaded resource files to
    ///   - progress: progress callback
    ///   - progressValue: the progress value, from 0 to 100
    ///   - completion: completion callback
    /// - Returns: a request that can be canceled
    func upload(resourceUrl: URL,
                target: MediaItemCore,
                progress: @escaping (_ progressValue: Int) -> Void,
                completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Delete a media
    ///
    /// - Parameters:
    ///   - media: the media to delete
    ///   - completion: completion callback
    ///   - success: whether the deletion was successful or not
    /// - Returns: a request that can be canceled
    func delete(media: MediaItemCore,
                completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Delete a media resource
    ///
    /// - Parameters:
    ///   - resource: the resource to delete
    ///   - completion: completion callback
    ///   - success: whether the deletion was successful or not
    /// - Returns: a request that can be canceled
    func delete(resource: MediaItemResourceCore,
                completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Delete all medias
    ///
    /// - Parameters:
    ///   - completion: completion callback
    ///   - success: whether the deletion was successful or not
    /// - Returns: a request that can be canceled
    func deleteAll(completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Informs the delegate that a command has been received
    ///
    /// - Parameter command: the command received
    func didReceiveCommand(_ command: OpaquePointer)
}

/// Media store peripheral controller that does access the media through http
class HttpMediaStore: ArsdkMediaStore {
    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    init(deviceController: DeviceController) {
        super.init(deviceController: deviceController,
                   api: HttpMediaStoreApi(deviceController: deviceController))
    }
}

/// Media Store peripheral controller
///
/// This class is abstract. See `HttpMediaStore` to create actual instances of this class.
class ArsdkMediaStore: DeviceComponentController {

    /// Media store component
    private var mediaStore: MediaStoreCore!

    /// The media store delegate.
    private let api: MediaStoreApi

    /// Constructor
    ///
    /// Visibility is fileprivate to force creation from `HttpMediaStore`.
    ///
    /// - Parameters:
    ///   - deviceController: device controller owning this component controller (weak)
    ///   - delegate: media access delegate
    fileprivate init(deviceController: DeviceController, api: MediaStoreApi) {
        self.api = api
        super.init(deviceController: deviceController)
        self.mediaStore = MediaStoreCore(
            store: deviceController.device.peripheralStore,
            thumbnailCache: MediaStoreThumbnailCacheCore(mediaStoreBackend: self,
                                                         size: kThumbnailCacheSize),
            backend: self)
        self.api.delegate = self
    }

    /// Drone is connected
    override func didConnect() {
        self.api.configure()
        self.mediaStore.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        self.mediaStore.unpublish()
        self.api.reset()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        self.api.didReceiveCommand(command)
    }
}

extension ArsdkMediaStore: MediaStoreApiDelegate {
    func receivedMediaStoreChangedEvent(_ event: MediaStoreApiChangeEvent) {
        self.mediaStore
            .markContentChanged(withEvent: event.gsdkEvent)
            .notifyUpdated()

    }

    func indexingStateChanged(_ indexingState: MediaStoreIndexingState) {
        self.mediaStore
            .update(indexingState: indexingState)
            .notifyUpdated()
    }

    func countersUpdated(videoMediaCount: Int, photoMediaCount: Int,
                         videoResourceCount: Int, photoResourceCount: Int) {
        self.mediaStore
            .update(photoMediaCount: photoMediaCount)
            .update(videoMediaCount: videoMediaCount)
            .update(photoResourceCount: photoResourceCount)
            .update(videoResourceCount: videoResourceCount)
            .notifyUpdated()
    }
}

/// MediaStore backend implementation
extension ArsdkMediaStore: MediaStoreBackend {

    /// Start watching media store content.
    ///
    /// When content watching is started, backend must call `markContentChanged()` when the content
    /// of the media store changes.
    func startWatchingContentChanges() {
        self.api.startWatchingContentChanges()
    }

    /// Stop watching media store content.
    func stopWatchingContentChanges() {
        self.api.stopWatchingContentChanges()
    }

    /// Browse medias.
    ///
    /// - Parameter completion: closure called when the request is terminated
    /// - Returns: browse request, or nil if there is an error
    public func browse(completion: @escaping ([MediaItemCore]) -> Void) -> CancelableCore? {
        self.api.browse(completion: completion)
    }

    /// Browse medias using a storage type.
    ///
    /// - Parameter storage: the storage where to list Medias
    /// - Parameter completion: closure called when the request is terminated
    /// - Returns: browse request, or nil if there is an error
    func browse(storage: StorageType?, completion: @escaping ([MediaItemCore]) -> Void) -> CancelableCore? {
        self.api.browse(storage: storage, completion: completion)
    }

    /// Download a thumbnail
    ///
    /// - Parameters:
    ///   - owner: owner to download the thumbnail for
    ///   - completion: closure called when the thumbnail has been downloaded or if there is an error.
    ///   - thumbnailData: downloaded thumbnail data, nil if there is a error
    /// - Returns: download thumbnail request, or nil if the request can't be send
    public func downloadThumbnail(for owner: MediaStoreThumbnailCacheCore.ThumbnailOwner,
                                  completion: @escaping (_ thumbnailData: Data?) -> Void)
    -> IdentifiableCancelableCore? {
        self.api.downloadThumbnail(for: owner, completion: completion)
    }

    /// Download a list of media resources
    ///
    /// - Parameters:
    ///   - resource: media resource to download
    ///   - type: download type
    ///   - destination: download destination
    ///   - progress: progress callback
    ///   - completion: closure called when the signature has been downloaded or if there is an error
    /// - Returns: download task, or nil if the request can't be send
    func download(resource: MediaItemResourceCore, type: DownloadType, destination: String,
                  progress: @escaping (Int) -> Void, completion: @escaping (URL?) -> Void) -> CancelableCore? {
        self.api.download(resource: resource, type: type, destDirectoryPath: destination,
                          progress: progress, completion: completion)
    }

    /// Download a signature resource
    ///
    /// - Parameters:
    ///   - resource: signature resource
    ///   - destDirectoryPath: download destination
    ///   - completion: closure called when the signature has been downloaded or if there is an error
    /// - Returns: download task, or nil if the request can't be send
    public func downloadSignature(resource: MediaItemResourceCore, destDirectoryPath: String,
                                  completion: @escaping (_ signatureUrl: URL?) -> Void) -> CancelableCore? {
        self.api.downloadSignature(resource: resource,
                                   destDirectoryPath: destDirectoryPath,
                                   completion: completion)
    }

    /// Uploads media resources.
    ///
    /// - Parameters:
    ///   - resources: resource files to upload
    ///   - target: target media item to attach uploaded resource files to
    ///   - progress: upload progress callback
    /// - Returns: resource upload request, or `nil` if the request can't be send.
    func upload(resources: [URL], target: MediaItemCore,
                progress: @escaping (ResourceUploader?) -> Void) -> CancelableCore? {

        /// Upload entry to be processed.
        struct Entry {
            /// URL of the file to upload.
            let url: URL
            /// File size, in bytes.
            let size: UInt64
        }

        var uploadedResourceCount = 0
        var uploadedResourceSize: UInt64 = 0
        let entries: [Entry] = resources.map { resource in
            var size: UInt64 = 0
            if let attrs = try? FileManager.default.attributesOfItem(atPath: resource.path) {
                size = attrs[.size] as? UInt64 ?? 0
            }
            return Entry(url: resource, size: size)
        }
        let totalSize = Float(entries.reduce(0, { $0 + $1.size }))
        var entriesIterator = entries.makeIterator()

        // create result request
        let task = CancelableTaskCore()

        /// Notify progress with current file.
        ///
        /// - Parameters:
        ///   - currentEntry: current file entry
        ///   - ratio: current file upload between 0.0 (0%) and 1.0 (100%)
        ///   - status: upload progress status
        func notifyProgress(currentEntry: Entry?, ratio: Float, status: MediaTaskStatus) {
            let totalProgress = (Float(uploadedResourceSize) + Float(currentEntry?.size ?? 0) * ratio) / totalSize
            progress(ResourceUploaderCore(targetMedia: target, totalResourceCount: entries.count,
                                          uploadedResourceCount: uploadedResourceCount, currentFileProgress: ratio,
                                          totalProgress: totalProgress, status: status,
                                          currentFileUrl: currentEntry?.url))
        }

        /// Uploads the next media resource.
        func uploadNextResource() {
            guard !task.canceled else {
                // don't do anything if the request has been canceled
                return
            }

            // Move to next resource entry
            if let entry = entriesIterator.next() {
                // request upload
                let req = self.api.upload(
                    resourceUrl: entry.url, target: target,
                    progress: { percent in
                        notifyProgress(currentEntry: entry, ratio: Float(percent) / 100, status: .running)
                    },
                    completion: { success in
                        task.request = nil
                        if success {
                            uploadedResourceCount += 1
                            notifyProgress(currentEntry: entry, ratio: 1.0, status: .fileDownloaded)
                            uploadedResourceSize += entry.size
                            uploadNextResource()
                        } else if !task.canceled {
                            ULog.w(.ctrlTag, "Error uploading media resource")
                            notifyProgress(currentEntry: entry, ratio: 0.0, status: .error)
                        }
                    })
                // request created, update client request and notify progress
                if let req = req {
                    // store current low level request to cancel
                    task.request = req
                    // progress for the new resource
                    notifyProgress(currentEntry: entry, ratio: 0.0, status: .running)
                } else {
                    // error sending request
                    ULog.d(.ctrlTag, "Error sending resource upload request")
                    notifyProgress(currentEntry: entry, ratio: 0.0, status: .error)
                }
            } else {
                // no more resources to upload
                ULog.d(.ctrlTag, "Resource upload terminated")
                notifyProgress(currentEntry: nil, ratio: 0.0, status: .complete)
            }
        }

        // start upload with the first resource
        uploadNextResource()
        return task
    }

    /// Delete medias resources
    ///
    /// - Parameters:
    ///   - mediaResources: list of media resources to delete
    ///   - progress: progress closure called after each deleted files
    /// - Returns: delete request, or nil if the request can't be send
    func delete(mediaResources: MediaResourceListCore,
                progress: @escaping (MediaDeleter) -> Void) -> CancelableCore? {
        // forward declare completion, as it's used in itself
        var completion: ((Bool) -> Void)!
        let entryIterator = mediaResources.makeIterator()
        let task = CancelableTaskCore()

        func deleteNext() {
            guard !task.canceled else {
                // don't do anything if the request has been canceled
                return
            }
            // move to next media or resource
            if let entry = entryIterator.nextMediaOrResource() {
                if let resource = entry.resource {
                    task.request = self.api.delete(resource: resource, completion: completion)
                } else {
                    task.request = self.api.delete(media: entry.media, completion: completion)
                }
                progress(MediaDeleterCore(mediaResourceListIterator: entryIterator, status: .running))
            } else {
                progress(MediaDeleterCore(mediaResourceListIterator: entryIterator, status: .complete))
            }
        }

        completion = { success in
            if success {
                deleteNext()
            } else {
                progress(MediaDeleterCore(mediaResourceListIterator: entryIterator, status: .error))
            }
        }

        // trig first delete
        deleteNext()

        return task
    }

    func deleteAll(progress: @escaping (AllMediasDeleter) -> Void) -> CancelableCore? {
        progress(AllMediasDeleterCore(status: .running))
        return CancelableTaskCore(request: self.api.deleteAll { success in
            let status: MediaTaskStatus = success ? .complete : .error
            progress(AllMediasDeleterCore(status: status))
        })
    }

    var indexingState: MediaStoreIndexingState {
        self.mediaStore.indexingState
    }
}
