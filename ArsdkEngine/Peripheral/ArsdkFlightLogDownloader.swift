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

/// FlightLog downloader delegate.
protocol ArsdkFlightLogDownloaderDelegate: AnyObject {
    /// Configures the delegate.
    ///
    /// - Parameter downloader: the downloader component
    func configure(downloader: FlightLogDownloaderCore)

    /// Resets the delegate.
    func reset()

    /// Starts watching flight log store content.
    func startWatchingContentChanges(arsdkDownloader: ArsdkFlightLogDownloader)

    /// Stops watching flight log store content.
    func stopWatchingContentChanges()

    /// Downloads all existing flight logs.
    func download()

    /// Deletes all existing flight logs.
    func delete()

    /// Cancel current request and all following ones.
    func cancel()
}

/// FlightLog downloader component controller subclass that does the download through http.
class HttpFlightLogDownloader: ArsdkFlightLogDownloader {
    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - flightLogStorage: flight Log Storage Utility
    init(deviceController: DeviceController, flightLogStorage: FlightLogStorageCore) {
        super.init(deviceController: deviceController,
                   delegate: HttpFlightLogDownloaderDelegate(deviceController: deviceController,
                                                             storage: flightLogStorage))
    }

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - flightLogConverterStorage: flight Log converter Storage Utility
    init(deviceController: DeviceController, flightLogConverterStorage: FlightLogConverterStorageCore) {
        super.init(deviceController: deviceController,
                   delegate: HttpFlightLogDownloaderDelegate(deviceController: deviceController,
                                                             converterStorage: flightLogConverterStorage))
    }
}

/// FlightLog downloader component controller subclass that does the download through ftp.
class FtpFlightLogDownloader: ArsdkFlightLogDownloader {

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - flightLogStorage: flight Log Storage Utility
    init(deviceController: DeviceController, flightLogStorage: FlightLogStorageCore) {
        super.init(deviceController: deviceController,
                   delegate: FtpFlightLogDownloaderDelegate(deviceController: deviceController,
                                                            storage: flightLogStorage))
    }
}

/// Generic flightLog downloader component controller.
class ArsdkFlightLogDownloader: DeviceComponentController {

    /// FlightLogDownloader component.
    private let flightLogDownloader: FlightLogDownloaderCore

    // swiftlint:disable weak_delegate
    /// Delegate to actually download the flight logs
    private let delegate: ArsdkFlightLogDownloaderDelegate
    // swiftlint:enable weak_delegate

    /// User Account Utility
    private var userAccountUtilityCore: UserAccountUtilityCore?

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - delegate: flight log downloader delegate
    fileprivate init(deviceController: DeviceController, delegate: ArsdkFlightLogDownloaderDelegate) {
        self.delegate = delegate
        self.flightLogDownloader = FlightLogDownloaderCore(store: deviceController.device.peripheralStore)
        self.userAccountUtilityCore =  deviceController.engine.utilities.getUtility(Utilities.userAccount)
        super.init(deviceController: deviceController)
    }

    /// Device is connected
    override func didConnect() {
        delegate.configure(downloader: flightLogDownloader)
        flightLogDownloader.publish()
    }

    /// Device is disconnected
    override func didDisconnect() {
        flightLogDownloader.unpublish()
        delegate.reset()
    }

    override func dataSyncAllowanceChanged(allowed: Bool) {
        if allowed {
            delegate.startWatchingContentChanges(arsdkDownloader: self)
            download()
        } else {
            delegate.stopWatchingContentChanges()
            cancelDownload()
        }
    }

    /// Downloads flight logs from the controlled device.
    /// In private mode, flight logs are just deleted instead of being downloaded.
    func download() {
        if userAccountUtilityCore?.userAccountInfo?.privateMode == true {
            delegate.delete()
        } else {
            delegate.download()
        }
    }

    /// Cancels current download.
    private func cancelDownload() {
        delegate.cancel()
    }
}
