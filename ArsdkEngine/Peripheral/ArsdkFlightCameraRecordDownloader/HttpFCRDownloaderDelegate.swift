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

/// FlightCameraRecord downloader delegate that does the download through http
class HttpFCRDownloaderDelegate: ArsdkFlightCameraRecordDownloaderDelegate {

    /// Device controller.
    private let deviceController: DeviceController

    /// Flight camera record storage utility.
    private let storage: FlightCameraRecordStorageCore

    /// Flight camera record downloader component.
    private var downloader: FlightCameraRecordDownloaderCore?

    /// Flight Camera record REST API.
    /// Not nil when uploader has been configured. Nil after a reset.
    private var flightCameraRecordApi: FlightCameraRecordRestApi?

    /// Flight Camera record WebSocket API.
    private var flightCameraRecordWsApi: FlightCameraRecordWsApi?

    /// List of pending downloads
    private var pendingDownloads: [FlightCameraRecordRestApi.FlightCameraRecord] = []

    /// FlightCameraRecord downloaded count.
    private var downloadCount = 0

    /// Whether or not the current overall task has been canceled
    private var isCanceled = false

    /// Whether or not available FCR list should be queried again.
    private var requery = false

    /// Current report download request
    /// - Note: this request can change during the overall download task (it can be the listing, downloading or deleting
    ///         request).
    private var currentRequest: CancelableCore?

    /// Device uid
    private var deviceUid: String = ""

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller
    ///     - storage: flight camera record storage utility
    init(deviceController: DeviceController, storage: FlightCameraRecordStorageCore) {
        self.deviceController = deviceController
        self.storage = storage
    }

    func configure(downloader: FlightCameraRecordDownloaderCore) {
        self.downloader = downloader
        if let droneServer = deviceController.droneServer {
            flightCameraRecordApi = FlightCameraRecordRestApi(server: droneServer)
        }
        deviceUid = deviceController.device.uid
    }

    func reset() {
        flightCameraRecordApi = nil
    }

    func startWatchingContentChanges(arsdkDownloader: ArsdkFlightCameraRecordDownloader) {
        if let droneServer = deviceController.droneServer {
            flightCameraRecordWsApi = FlightCameraRecordWsApi(server: droneServer) {
                arsdkDownloader.download()
            }
        }
    }

    func stopWatchingContentChanges() {
        flightCameraRecordWsApi = nil
    }

    func download() {
        guard flightCameraRecordApi != nil else {
            return
        }
        guard currentRequest == nil else {
            requery = true
            return
        }

        downloadCount = 0
        isCanceled = false
        self.downloader?.update(completionStatus: .none)
            .update(downloadingFlag: true)
            .update(downloadedCount: downloadCount)
            .notifyUpdated()

        queryRecordList()
    }

    func delete() {
        guard flightCameraRecordApi != nil else {
            return
        }
        guard currentRequest == nil else {
            requery = true
            return
        }

        isCanceled = false

        queryRecordListForDeletion()
    }

    func cancel() {
        isCanceled = true
        // empty the list of pending downloads
        pendingDownloads = []
        currentRequest?.cancel()
    }

    /// Queries available FCR files from the drone.
    /// In case some files are available, starts downloading them.
    private func queryRecordList() {
        currentRequest = flightCameraRecordApi?.getFlightCameraRecordList { flightCameraRecordList in
            if let flightCameraRecordList = flightCameraRecordList {
                self.pendingDownloads = flightCameraRecordList.sorted { $0.date > $1.date }

                let list = self.pendingDownloads.map { $0.name }.joined(separator: ",")
                GroundSdkCore.logEvent(message: "EVT:LOGS;event='list';source='drone';files='\(list)'")

                self.downloadNextCameraRecord()
            } else {
                self.downloader?.update(completionStatus: .interrupted)
                    .update(downloadingFlag: false)
                    .notifyUpdated()
                self.currentRequest = nil
            }
        }
    }

    /// Download next camera record.
    private func downloadNextCameraRecord() {
        if requery {
            requery = false
            queryRecordList()
            return
        }

        if let flightCameraRecord = pendingDownloads.first {
            currentRequest = flightCameraRecordApi?.downloadFlightCameraRecord(
                flightCameraRecord, toDirectory: storage.workDir, deviceUid: deviceUid) { fileUrl in
                if let fileUrl = fileUrl {
                    self.deleteFlightCameraRecordAndDownloadNext(flightCameraRecord: flightCameraRecord,
                                                                 fileUrl: fileUrl)
                } else {
                    // even if the download failed, process next report
                    if !self.pendingDownloads.isEmpty {
                        self.pendingDownloads.removeFirst()
                    }
                    self.downloadNextCameraRecord()
                }
            }
        } else {
            if isCanceled {
                self.downloader?.update(completionStatus: .interrupted)
            } else {
                self.downloader?.update(completionStatus: .success)
            }
            self.downloader?.update(downloadingFlag: false).notifyUpdated()
            currentRequest = nil
            isCanceled = false
        }
    }

    /// Delete flight camera record and start download for the next one
    ///
    /// - Parameters:
    ///   - flightCameraRecord: flight camera record to delete
    ///   - fileUrl: file url
    private func deleteFlightCameraRecordAndDownloadNext(
        flightCameraRecord: FlightCameraRecordRestApi.FlightCameraRecord, fileUrl: URL) {
        // delete the distant report
        currentRequest = flightCameraRecordApi?.deleteFlightCameraRecord(flightCameraRecord) { _ in
            self.downloadCount += 1
            self.downloader?.update(downloadedCount: self.downloadCount).notifyUpdated()
            self.storage.notifyFlightCameraRecordReady(flightCameraRecordUrl: URL(fileURLWithPath: fileUrl.path))
            GroundSdkCore.logEvent(message: "EVT:LOGS;event='download';source='drone';" +
                "file='\(fileUrl.lastPathComponent)'")
            // even if the deletion failed, process next report
            if !self.pendingDownloads.isEmpty {
                self.pendingDownloads.removeFirst()
            }
            // download next camera record
            self.downloadNextCameraRecord()
        }
    }

    /// Queries available FCR files from the drone.
    /// In case some files are available, starts deleting them.
    private func queryRecordListForDeletion() {
        currentRequest = flightCameraRecordApi?.getFlightCameraRecordList { flightCameraRecordList in
            if let flightCameraRecordList = flightCameraRecordList {
                self.pendingDownloads = flightCameraRecordList
                self.deleteNextCameraRecord()
            } else {
                self.currentRequest = nil
            }
        }
    }

    /// Delete next log.
    private func deleteNextCameraRecord() {
        if requery {
            requery = false
            queryRecordListForDeletion()
            return
        }

        if let flightCameraRecord = pendingDownloads.first {
            currentRequest = flightCameraRecordApi?.deleteFlightCameraRecord(flightCameraRecord) { _ in
                // even if the deletion failed, process next record
                if !self.pendingDownloads.isEmpty {
                    self.pendingDownloads.removeFirst()
                }
                self.deleteNextCameraRecord()
            }
        } else {
            currentRequest = nil
            isCanceled = false
        }
    }
}
