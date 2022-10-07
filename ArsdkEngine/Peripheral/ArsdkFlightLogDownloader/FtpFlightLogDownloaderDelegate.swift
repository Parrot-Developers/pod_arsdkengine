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

/// FlightLog downloader delegate that does the download through ftp.
class FtpFlightLogDownloaderDelegate: ArsdkFlightLogDownloaderDelegate {

    /// Device controller.
    private let deviceController: DeviceController

    /// Flight log storage utility.
    private let storage: FlightLogStorageCore

    /// Flight log downloader component.
    private var downloader: FlightLogDownloaderCore?

    /// FlightLog downloaded count.
    private var downloadCount = 0

    /// Current flightLog download request
    private var currentRequest: CancelableCore?

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller
    ///     - storage: flight log storage utility
    init(deviceController: DeviceController, storage: FlightLogStorageCore) {
        self.deviceController = deviceController
        self.storage = storage
    }

    func configure(downloader: FlightLogDownloaderCore) {
        self.downloader = downloader
    }

    func reset() { }

    func startWatchingContentChanges(arsdkDownloader: ArsdkFlightLogDownloader) { }

    func stopWatchingContentChanges() { }

    func download() {
        guard currentRequest == nil else {
            return
        }

        downloadCount = 0
        downloader?.update(completionStatus: .none)
            .update(downloadingFlag: true)
            .update(downloadedCount: downloadCount)
            .notifyUpdated()

        currentRequest = deviceController.downloadFlightLog(
            path: storage.workDir.path,
            progress: { [weak self] file, status in
                if status == .ok, let `self` = self {
                    self.downloadCount += 1
                    self.downloader?.update(downloadedCount: self.downloadCount).notifyUpdated()
                    let filePath = URL(fileURLWithPath: file)
                    self.storage.notifyFlightLogReady(flightLogUrl: filePath)
                    GroundSdkCore.logEvent(message: "EVT:LOGS;event='download';source='ctrl';" +
                                           "file='\(filePath.lastPathComponent)'")
                }
            },
            completion: { status in
                let success = status == .ok
                self.downloader?.update(completionStatus: success ? .success : .interrupted)
                    .update(downloadingFlag: false)
                    .notifyUpdated()
                self.currentRequest = nil
        })
    }

    func delete() {
        // Not implemented
    }

    func cancel() {
        currentRequest?.cancel()
    }
}
