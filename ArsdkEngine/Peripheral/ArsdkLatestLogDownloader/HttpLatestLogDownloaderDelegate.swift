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

/// Latest log downloader delegate that does the download through http.
class HttpLatestLogDownloaderDelegate: ArsdkLatestLogDownloaderDelegate {

    /// Flight Log REST Api.
    /// Not `nil` when uploader has been configured. `nil` after a reset.
    private var flightLogApi: FlightLogRestApi?

    /// Device uid
    private var deviceUid: String = ""

    /// List of pending downloads.
    private var pendingDownloads: [FlightLogRestApi.FlightLog] = []

    /// Whether or not the current overall task has been canceled.
    private var isCanceled = false

    /// Current report download request.
    /// - Note: this request can change during the overall download task (it can be the listing or downloading request).
    private var currentRequest: CancelableCore?

    /// Size of the log files downloaded so far, in bytes.
    private var downloadedLogsSize: UInt64 = 0

    func configure(downloader: ArsdkLatestLogDownloader) {
        if let droneServer = downloader.deviceController.deviceServer {
            flightLogApi = FlightLogRestApi(server: droneServer)
        }
        deviceUid = downloader.deviceController.device.uid
    }

    func reset(downloader: ArsdkLatestLogDownloader) {
        flightLogApi = nil
    }

    func download(toDirectory directory: URL, downloader: ArsdkLatestLogDownloader) -> Bool {
        guard currentRequest == nil else {
            return false
        }

        isCanceled = false
        downloadedLogsSize = 0
        currentRequest = flightLogApi?.getFlightLogListForBootId { flightLogList in
            if let flightLogList = flightLogList {
                let totalSize = flightLogList.reduce(0) { sum, log in sum + log.size }
                downloader.latestLogDownloader.update(totalSize: totalSize)
                    .update(collectedSize: 0)
                    .notifyUpdated()

                self.pendingDownloads = flightLogList.sorted { $0.date > $1.date }
                self.downloadNextLog(toDirectory: directory, downloader: downloader)
            } else {
                downloader.latestLogDownloader.update(status: self.isCanceled ? .canceled : .failed).notifyUpdated()
                self.currentRequest = nil
            }
        }

        return currentRequest != nil
    }

    func cancel() {
        isCanceled = true
        // empty the list of pending downloads
        pendingDownloads = []
        currentRequest?.cancel()
    }

    /// Downloads next log.
    ///
    /// - Parameters:
    ///   - directory: directory in which flight logs should be stored
    ///   - downloader: the downloader in charge
    private func downloadNextLog(toDirectory directory: URL, downloader: ArsdkLatestLogDownloader) {
        if let flightLog = pendingDownloads.first {
            currentRequest = flightLogApi?.downloadFlightLog(
                flightLog, toDirectory: directory, deviceUid: deviceUid,
                progress: { progressValue in
                    downloader.latestLogDownloader
                        .update(collectedSize: self.downloadedLogsSize + flightLog.size * UInt64(progressValue) / 100)
                        .notifyUpdated()
                },
                completion: { fileUrl in
                    if fileUrl != nil {
                        self.downloadedLogsSize += flightLog.size
                        downloader.latestLogDownloader
                            .update(collectedSize: self.downloadedLogsSize)
                            .notifyUpdated()
                    }
                    if !self.pendingDownloads.isEmpty {
                        self.pendingDownloads.removeFirst()
                    }
                    // process next report even if the download failed
                    self.downloadNextLog(toDirectory: directory, downloader: downloader)
                })
        } else {
            downloader.latestLogDownloader.update(status: isCanceled ? .canceled : .collected).notifyUpdated()
            currentRequest = nil
            isCanceled = false
        }
    }
}
