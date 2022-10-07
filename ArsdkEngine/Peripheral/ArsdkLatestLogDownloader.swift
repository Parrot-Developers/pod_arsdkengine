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

/// Latest log downloader delegate.
protocol ArsdkLatestLogDownloaderDelegate: AnyObject {

    /// Configures the delegate.
    ///
    /// - Parameter downloader: the downloader in charge
    func configure(downloader: ArsdkLatestLogDownloader)

    /// Resets the delegate.
    ///
    /// - Parameter downloader: the downloader in charge
    func reset(downloader: ArsdkLatestLogDownloader)

    /// Downloads logs matching the current boot id.
    ///
    /// - Parameters:
    ///   - directory: the local directory to store the logs
    ///   - downloader: the downloader in charge
    /// - Returns: `true` if the download has been started, `false` otherwise
    func download(toDirectory directory: URL, downloader: ArsdkLatestLogDownloader) -> Bool

    /// Cancels current request and all following ones.
    func cancel()
}

/// Latest log downloader component controller.
class ArsdkLatestLogDownloader: DeviceComponentController {

    /// LatestLogDownloader component.
    var latestLogDownloader: LatestLogDownloaderCore!

    // swiftlint:disable weak_delegate
    /// Delegate to actually download the flight logs
    let delegate: ArsdkLatestLogDownloaderDelegate
    // swiftlint:enable weak_delegate

    /// Constructor.
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - logStorage: flight Log Storage Utility
    ///     - delegate: flight log downloader delegate
    override init(deviceController: DeviceController) {
        delegate = HttpLatestLogDownloaderDelegate()
        super.init(deviceController: deviceController)
        latestLogDownloader = LatestLogDownloaderCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Device is connected.
    override func didConnect() {
        delegate.configure(downloader: self)
        latestLogDownloader.publish()
    }

    /// Device is disconnected.
    override func didDisconnect() {
        latestLogDownloader.unpublish()
        delegate.reset(downloader: self)
    }
}

/// LatestLogDownloader backend implementation.
extension ArsdkLatestLogDownloader: LatestLogDownloaderBackend {

    func downloadLogs(toDirectory directory: URL) {
        if delegate.download(toDirectory: directory, downloader: self) {
            latestLogDownloader.update(status: .collecting)
                .update(totalSize: nil)
                .update(collectedSize: nil)
                .notifyUpdated()
        }
    }

    func cancelDownload() {
        delegate.cancel()
    }
}
