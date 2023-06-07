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

/// Wifi scanner command delegate.
protocol WifiScannerCommandDelegate: AnyObject {

    /// Sends command to scan channels occupation rate.
    ///
    /// - Parameter radioId: radio identifier
    /// - Returns: `true` if the command has been sent, `false` otherwise
    func scan(radioId: UInt32) -> Bool
}

/// Wifi radio scanner component controller.
class WifiScannerController: RadioComponentController {

    /// Wifi scanner component.
    private var wifiScanner: WifiScannerCore!

    /// Command delegate.
    private unowned let delegate: WifiScannerCommandDelegate

    /// Radio identifier.
    private let radioId: UInt32

    /// Constructor.
    ///
    /// - Parameters:
    ///    - store: store where the peripheral will be stored
    ///    - delegate: command delegate
    ///    - radioId: identifies the radio this component belongs to
    init(store: ComponentStoreCore, delegate: WifiScannerCommandDelegate, radioId: UInt32) {
        self.delegate = delegate
        self.radioId = radioId
        self.wifiScanner = WifiScannerCore(store: store, backend: self)
    }

    func didDisconnect() {
        wifiScanner.unpublish()
    }

    func processStateEvent(state: Arsdk_Connectivity_Event.State) {
        wifiScanner.publish()
    }

    func processScanResult(scanResult: Arsdk_Connectivity_Event.ScanResult) {
        guard wifiScanner.scanning else { return }

        let scanResults = scanResult.networks.map {
            var channel: WifiChannel?
            if $0.hasChannel,
               case .wifiChannel(let arsdkChannel) = $0.channel.type {
                channel = WifiChannel(fromArsdk: arsdkChannel)
            }
            return ScanResult(ssid: $0.ssid, channel: channel)
        }
        wifiScanner.update(scanResults: scanResults).notifyUpdated()

        // keep on scanning
        _ = delegate.scan(radioId: radioId)
    }
}

/// Wifi scanner backend implementation.
extension WifiScannerController: WifiScannerBackend {

    func startScan() {
        _ = delegate.scan(radioId: radioId)

        wifiScanner.update(scanning: true)
            .update(scanResults: [])
            .notifyUpdated()
    }

    func stopScan() {
        wifiScanner.update(scanning: false)
            .update(scanResults: [])
            .notifyUpdated()
    }
}
