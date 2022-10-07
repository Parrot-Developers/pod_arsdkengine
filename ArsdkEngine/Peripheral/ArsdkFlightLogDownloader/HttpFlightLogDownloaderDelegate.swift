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

/// FlightLog downloader delegate that does the download through http.
class HttpFlightLogDownloaderDelegate: ArsdkFlightLogDownloaderDelegate {

    /// Device controller.
    private let deviceController: DeviceController

    /// Flight log storage utility, `nil` if `converterStorage` is not `nil`.
    private let storage: FlightLogStorageCore?

    /// Flight log converter storage utility, `nil` if `storage` is not `nil`.
    private let converterStorage: FlightLogConverterStorageCore?

    /// Flight log downloader component.
    private var downloader: FlightLogDownloaderCore?

    /// Flight log REST API.
    /// Not nil when uploader has been configured. Nil after a reset.
    private var flightLogApi: FlightLogRestApi?

    /// Flight log WebSocket API.
    private var flightLogWsApi: FlightLogWsApi?

    /// List of pending downloads.
    private var pendingDownloads: [FlightLogRestApi.FlightLog] = []

    /// FlightLog downloaded count.
    private var downloadCount = 0

    /// Whether or not the current overall task has been canceled.
    private var isCanceled = false

    /// Whether or not available flight log list should be queried again.
    private var requery = false

    /// Current log download request.
    /// - Note: this request can change during the overall download task (it can be the listing, downloading or deleting
    ///         request).
    private var currentRequest: CancelableCore?

    /// Device uid.
    private var deviceUid: String = ""

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller
    ///     - storage: flight log storage utility
    init(deviceController: DeviceController, storage: FlightLogStorageCore) {
        self.deviceController = deviceController
        self.storage = storage
        self.converterStorage = nil
    }

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller
    ///     - converterStorage: flight log converter storage utility
    init(deviceController: DeviceController, converterStorage: FlightLogConverterStorageCore) {
        self.deviceController = deviceController
        self.storage = nil
        self.converterStorage = converterStorage
    }

    func configure(downloader: FlightLogDownloaderCore) {
        self.downloader = downloader
        if let droneServer = deviceController.deviceServer {
            flightLogApi = FlightLogRestApi(server: droneServer)
        }
        deviceUid = deviceController.device.uid
    }

    func reset() {
        flightLogApi = nil
    }

    func startWatchingContentChanges(arsdkDownloader: ArsdkFlightLogDownloader) {
        if let droneServer = deviceController.deviceServer {
            flightLogWsApi = FlightLogWsApi(server: droneServer) {
                arsdkDownloader.download()
            }
        }
    }

    func stopWatchingContentChanges() {
        flightLogWsApi = nil
    }

    func download() {
        guard flightLogApi != nil else {
            return
        }
        guard currentRequest == nil else {
            requery = true
            return
        }

        downloadCount = 0
        isCanceled = false
        downloader?.update(completionStatus: .none)
            .update(downloadingFlag: true)
            .update(downloadedCount: downloadCount)
            .notifyUpdated()

        queryFlightLogList()
    }

    func delete() {
        guard flightLogApi != nil else {
            return
        }
        guard currentRequest == nil else {
            requery = true
            return
        }

        isCanceled = false

        queryFlightLogListForDeletion()
    }

    func cancel() {
        isCanceled = true
        // empty the list of pending downloads
        pendingDownloads = []
        currentRequest?.cancel()
    }

    /// Queries available flight logs from the drone.
    /// In case some logs are available, starts downloading them.
    private func queryFlightLogList() {
        currentRequest = flightLogApi?.getFlightLogList { flightLogList in
            if let flightLogList = flightLogList {
                self.pendingDownloads = flightLogList.sorted { $0.date > $1.date }

                let deviceModel = ((self.deviceController as? DroneController) != nil) ? "drone" : "ctrl"
                let list = self.pendingDownloads.map { $0.name }.joined(separator: ",")
                GroundSdkCore.logEvent(message: "EVT:LOGS;event='list';source='\(deviceModel)';files='\(list)'")

                self.downloadNextLog()
            } else {
                self.downloader?.update(completionStatus: .interrupted)
                    .update(downloadingFlag: false)
                    .notifyUpdated()
                self.currentRequest = nil
            }
        }
    }

    /// Downloads next flight log.
    private func downloadNextLog() {
        if requery {
            requery = false
            queryFlightLogList()
            return
        }
        guard let destDir = storage?.workDir ?? converterStorage?.workDir else {
            return
        }

        if let flightLog = pendingDownloads.first {
            currentRequest = flightLogApi?.downloadFlightLog(
                flightLog, toDirectory: destDir, deviceUid: deviceUid,
                progress: { _ in },
                completion: { fileUrl in
                    if let fileUrl = fileUrl {
                        // delete flight log and download next flight log
                        self.deleteFlightLogAndDownloadNext(flightLog: flightLog, fileUrl: fileUrl)
                    } else {
                        // even if the download failed, process next log
                        if !self.pendingDownloads.isEmpty {
                            self.pendingDownloads.removeFirst()
                        }
                        self.downloadNextLog()
                    }
                })
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

    /// Deletes flight log from the remote device and starts downloading the next one.
    ///
    /// - Parameters:
    ///   - flightLog: flight log to delete
    ///   - fileUrl: URL of the uploaded file
    private func deleteFlightLogAndDownloadNext(flightLog: FlightLogRestApi.FlightLog, fileUrl: URL) {
        currentRequest = flightLogApi?.deleteFlightLog(flightLog) { _ in
            self.downloadCount += 1
            self.downloader?.update(downloadedCount: self.downloadCount).notifyUpdated()

            self.storage?.notifyFlightLogReady(flightLogUrl: URL(fileURLWithPath: fileUrl.path))
            self.converterStorage?.notifyFlightLogReady(flightLogUrl: URL(fileURLWithPath: fileUrl.path))

            let deviceModel = ((self.deviceController as? DroneController) != nil) ? "drone" : "ctrl"
            GroundSdkCore.logEvent(message: "EVT:LOGS;event='download';source='\(deviceModel)';" +
                "file='\(fileUrl.lastPathComponent)'")

            // even if the deletion failed, process next log
            if !self.pendingDownloads.isEmpty {
                self.pendingDownloads.removeFirst()
            }

            // download next flight log
            self.downloadNextLog()
        }
    }

    /// Queries available flight logs from the drone.
    /// In case some logs are available, starts deleting them.
    private func queryFlightLogListForDeletion() {
        currentRequest = flightLogApi?.getFlightLogList { flightLogList in
            if let flightLogList = flightLogList {
                self.pendingDownloads = flightLogList
                self.deleteNextLog()
            } else {
                self.currentRequest = nil
            }
        }
    }

    /// Deletes next flight log.
    private func deleteNextLog() {
        if requery {
            requery = false
            queryFlightLogListForDeletion()
            return
        }

        if let flightLog = pendingDownloads.first {
            currentRequest = flightLogApi?.deleteFlightLog(flightLog) { _ in
                // even if the deletion failed, process next log
                if !self.pendingDownloads.isEmpty {
                    self.pendingDownloads.removeFirst()
                }
                self.deleteNextLog()
            }
        } else {
            currentRequest = nil
            isCanceled = false
        }
    }
}
