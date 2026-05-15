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

/// The dted store api change event that comes from the `DtedStoreApiDelegate`.
enum DtedStoreApiChangeEvent {
    /// terrain added
    case terrainAdded(_ file: DtedRestApi.File)

    /// terrain removed
    case terrainRemoved

    enum CodingKeys: String, CodingKey {
        case terrain
    }

    /// The GroundSdk representation of itself.
    var gsdkEvent: DtedStoreChangeEvent {
        switch self {
        case .terrainAdded(let file):
            return .terrainAdded(DtedFileCore.from(httpFile: file)!)
        case.terrainRemoved:
            return .terrainRemoved
        }
    }
}

/// The dted store api delegate callbacks.
protocol DtedStoreApiDelegate: AnyObject {

    /// Invoked when a dted store change event occurs.
    func receivedDtedStoreChangedEvent(_ event: DtedStoreApiChangeEvent)
}

/// Dted store API
protocol DtedStoreApi: AnyObject {

    /// The dted store api delegate
    var delegate: DtedStoreApiDelegate? { get set }

    /// Configure the delegate
    func configure()

    /// Reset the delegate
    func reset()

    /// Start watching dted store content.
    ///
    /// When content watching is started, backend must call `dtedStore.markContentChanged()`
    /// when the content of the dted store changes.
    func startWatchingContentChanges()

    /// Stop watching dted store content.
    func stopWatchingContentChanges()

    /// Get the list of dted files on the drone
    ///
    /// - Parameters:
    ///   - completion: closure that will be called when browsing did finish
    ///   - files: list of dted files on the device
    /// - Returns: a request that can be canceled
    func browse(completion: @escaping (_ files: [DtedFileCore]) -> Void) -> CancelableCore?

    /// Get the dted file from location.
    ///
    /// - Parameters:
    ///   - latitude: the location latitude
    ///   - longitude: the location longitude
    ///   - completion: closure called when the request is terminated
    /// - Returns: browse request, or nil if there is an error
    func get(latitude: Double, longitude: Double, completion: @escaping (DtedFileCore?) -> Void) -> CancelableCore?

    /// Uploads a dted file.
    ///
    /// - Parameters:
    ///   - fileUrl: the file to upload
    ///   - progress: progress callback
    ///   - progressValue: the progress value, from 0 to 100
    ///   - completion: completion callback
    /// - Returns: a request that can be canceled
    func upload(fileUrl: URL,
                progress: @escaping (_ progressValue: Int) -> Void,
                completion: @escaping (_ success: Bool) -> Void) -> CancelableCore?

    /// Delete dted file
    ///
    /// - Parameters:
    ///   - fileName: file name to delete
    ///   - completion: completion callback
    /// - Returns: delete request, or `nil` if the request can't be sent
    func delete(fileName: String, completion: @escaping (_ success: Bool) -> Void)
    -> CancelableCore?
}

/// Dted store peripheral controller that does access the file through http
class HttpDtedStore: ArsdkDtedStore {
    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    init(deviceController: DeviceController) {
        super.init(deviceController: deviceController,
                   api: HttpDtedStoreApi(deviceController: deviceController))
    }
}

/// Dted Store peripheral controller
///
/// This class is abstract. See `HttpDtedStore` to create actual instances of this class.
class ArsdkDtedStore: DeviceComponentController {

    /// Dted store component
    private var dtedStore: DtedStoreCore!

    /// The Dted store delegate.
    private let api: DtedStoreApi

    /// Constructor
    ///
    /// Visibility is fileprivate to force creation from `HttpDtedStore`.
    ///
    /// - Parameters:
    ///   - deviceController: device controller owning this component controller (weak)
    ///   - delegate: Dted access delegate
    fileprivate init(deviceController: DeviceController, api: DtedStoreApi) {
        self.api = api
        super.init(deviceController: deviceController)
        self.dtedStore = DtedStoreCore(
            store: deviceController.device.peripheralStore,
            backend: self)
        self.api.delegate = self
    }

    /// Drone is connected
    override func didConnect() {
        self.api.configure()
        self.dtedStore.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        self.dtedStore.unpublish()
        self.api.reset()
    }
}

extension ArsdkDtedStore: DtedStoreApiDelegate {
    func receivedDtedStoreChangedEvent(_ event: DtedStoreApiChangeEvent) {
        self.dtedStore
            .markContentChanged(withEvent: event.gsdkEvent)
            .notifyUpdated()

    }
}

/// DtedStore backend implementation
extension ArsdkDtedStore: DtedStoreBackend {

    /// Start watching dted store content.
    ///
    /// When content watching is started, backend must call `markContentChanged()` when the content
    /// of the dted store changes.
    func startWatchingContentChanges() {
        self.api.startWatchingContentChanges()
    }

    /// Stop watching dted store content.
    func stopWatchingContentChanges() {
        self.api.stopWatchingContentChanges()
    }

    /// Browse dted files.
    ///
    /// - Parameter completion: closure called when the request is terminated
    /// - Returns: browse request, or nil if there is an error
    public func browse(completion: @escaping ([DtedFileCore]) -> Void) -> CancelableCore? {
        self.api.browse(completion: completion)
    }

    /// Requests the DTED file from the store at specified location.
    ///
    /// - Parameters:
    ///   - latitude: latitude of location for which file is requested
    ///   - longitude: longitude of location for which file is requested
    ///   - completion: closure called when the request is terminated
    /// - Returns: a get request that can be canceled, or `nil` if there is an error
    public func get(latitude: Double, longitude: Double, completion: @escaping (DtedFileCore?) -> Void) -> CancelableCore? {
        self.api.get(latitude: latitude, longitude: longitude, completion: completion)
    }

    /// Uploads dted file.
    ///
    /// - Parameters:
    ///   - files: dted files to upload
    ///   - progress: upload progress callback
    /// - Returns: resource upload request, or `nil` if the request can't be send.
    func upload(files: [URL],
                progress: @escaping (DtedUploader?) -> Void) -> CancelableCore? {

        /// Upload entry to be processed.
        struct Entry {
            /// URL of the file to upload.
            let url: URL
            /// File size, in bytes.
            let size: UInt64
        }

        var uploadedFileCount = 0
        var uploadedFileSize: UInt64 = 0
        let entries: [Entry] = files.map { file in
            var size: UInt64 = 0
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path) {
                size = attrs[.size] as? UInt64 ?? 0
            }
            return Entry(url: file, size: size)
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
        func notifyProgress(currentEntry: Entry?, ratio: Float, status: DtedTaskStatus) {
            let totalProgress = (Float(uploadedFileSize) + Float(currentEntry?.size ?? 0) * ratio) / totalSize
            progress(DtedUploaderCore(totalFileCount: entries.count,
                                      uploadedFileCount: uploadedFileCount, currentFileProgress: ratio,
                                      totalProgress: totalProgress, status: status,
                                      currentFileUrl: currentEntry?.url))
        }

        /// Uploads the next file.
        func uploadNextFile() {
            guard !task.canceled else {
                // don't do anything if the request has been canceled
                return
            }

            // Move to next file entry
            if let entry = entriesIterator.next() {
                if entry.size > 0 {
                    // request upload
                    let req = self.api.upload(
                        fileUrl: entry.url,
                        progress: { percent in
                            notifyProgress(currentEntry: entry, ratio: Float(percent) / 100, status: .running)
                        },
                        completion: { success in
                            task.request = nil
                            if success {
                                uploadedFileCount += 1
                                notifyProgress(currentEntry: entry, ratio: 1.0, status: .currentUploadSuccess)
                                uploadedFileSize += entry.size
                                uploadNextFile()
                            } else if !task.canceled {
                                ULog.w(.ctrlTag, "Error uploading file")
                                notifyProgress(currentEntry: entry, ratio: 0.0, status: .aborted)
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
                        ULog.d(.ctrlTag, "Error sending file upload request")
                        notifyProgress(currentEntry: entry, ratio: 0.0, status: .aborted)
                    }
                } else {
                    ULog.w(.ctrlTag, "Error uploading empty file")
                    uploadNextFile()
                }
            } else {
                // no more files to upload
                ULog.d(.ctrlTag, "File upload terminated")
                notifyProgress(currentEntry: nil, ratio: 0.0, status: .complete)
            }
        }

        // start upload with the first file
        uploadNextFile()
        return task
    }

    /// Deletes dted files.
    ///
    /// - Parameters:
    ///   - files: dted files to delete
    ///   - progress: upload progress callback
    /// - Returns: resource upload request, or `nil` if the request can't be send.
    func delete(files: [DtedFile], progress: @escaping (DtedDeleter) -> Void)
    -> CancelableCore? {

        // forward declare completion, as it's used in itself
        var completion: ((Bool) -> Void)!
        var deletedFileCount = 0
        let task = CancelableTaskCore()

        func deleteNext() {
            guard !task.canceled else {
                // don't do anything if the request has been canceled
                return
            }
            // move to next file
            if deletedFileCount < files.count {
                let file = files[deletedFileCount]
                task.request =  self.api.delete(fileName: file.name, completion: completion)
                progress(DtedDeleter(totalCount: files.count, currentCount: deletedFileCount, status: .running))
            } else {
                progress(DtedDeleter(totalCount: files.count, currentCount: deletedFileCount, status: .complete))
            }
        }

        completion = { success in
            if success {
                deletedFileCount += 1
                deleteNext()
            } else {
                progress(DtedDeleter(totalCount: files.count, currentCount: deletedFileCount, status: .aborted))
            }
        }

        // trig first delete
        deleteNext()
        return task
    }
}
