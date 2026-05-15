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

// swiftlint:disable type_name
/// FlightCameraRecord downloader delegate
protocol ArsdkFlightCameraRecordDownloaderDelegate: AnyObject {
    /// Configure the delegate
    ///
    /// - Parameter downloader: the downloader component
    func configure(downloader: FlightCameraRecordDownloaderCore)

    /// Reset the delegate
    func reset()

    /// Start watching FCR store content
    func startWatchingContentChanges(arsdkDownloader: ArsdkFlightCameraRecordDownloader)

    /// Stop watching FCR store content
    func stopWatchingContentChanges()

    /// Download all existing flight camera records
    func download()

    /// Deletes all existing flight camera records.
    func delete()

    /// Cancel current request and all following ones.
    func cancel()
}
// swiftlint:enable type_name

/// Flight camera record downloader component controller subclass that does the download through http
class HttpFlightCameraRecordDownloader: ArsdkFlightCameraRecordDownloader {
    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - flightCameraRecordStorage: flight camera record Storage Utility
    init(deviceController: DeviceController,
         flightCameraRecordStorage: FlightCameraRecordStorageCore) {
        super.init(deviceController: deviceController,
                   delegate: HttpFCRDownloaderDelegate(deviceController: deviceController,
                                                       storage: flightCameraRecordStorage))
    }
}

/// Generic flight camera record downloader component controller
class ArsdkFlightCameraRecordDownloader: DeviceComponentController {

    /// Flight camera record downloader component.
    private let flightCameraRecordDownloader: FlightCameraRecordDownloaderCore

    // swiftlint:disable weak_delegate
    /// Delegate to actually download the flight camera records
    private let delegate: ArsdkFlightCameraRecordDownloaderDelegate
    // swiftlint:enable weak_delegate

    /// User Account Utility
    private var userAccountUtilityCore: UserAccountUtilityCore?

    /// Constructor
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - delegate: flight camera record downloader delegate
    fileprivate init(deviceController: DeviceController, delegate: ArsdkFlightCameraRecordDownloaderDelegate) {
        self.delegate = delegate
        self.flightCameraRecordDownloader = FlightCameraRecordDownloaderCore(
            store: deviceController.device.peripheralStore)
        self.userAccountUtilityCore =  deviceController.engine.utilities.getUtility(Utilities.userAccount)
        super.init(deviceController: deviceController)
    }

    /// Device is connected
    override func didConnect() {
        delegate.configure(downloader: flightCameraRecordDownloader)
        flightCameraRecordDownloader.publish()
    }

    /// Device is disconnected
    override func didDisconnect() {
        flightCameraRecordDownloader.unpublish()
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

    /// Downloads flight camera records from the controlled device.
    /// In private mode, records are just deleted instead of being downloaded.
    public func download() {
        if userAccountUtilityCore?.userAccountInfo?.privateMode == true {
            delegate.delete()
        } else {
            delegate.download()
        }
    }

    /// Cancels current download
    private func cancelDownload() {
        delegate.cancel()
    }
}
