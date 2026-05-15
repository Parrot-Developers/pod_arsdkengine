// Copyright (C) 2024 Parrot Drones SAS
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

/// Controller that retrieves data for stream sharing overlay from SkyController family remote controls.
class SkyControllerStreamSharingOverlay: DeviceComponentController {

    /// Stream sharing manager utility.
    private var streamSharingManager: StreamSharingManager?

    /// Stream sharing manager monitor.
    private var streamSharingMonitor: MonitorCore?

    /// Latest battery level
    private var batteryLevel: Int?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        streamSharingManager = deviceController.engine.utilities.getUtility(Utilities.streamSharingManager)
    }

    override func didConnect() {
        streamSharingMonitor = streamSharingManager?.startMonitoring(
            didEnable: {},
            serviceDidStart: {},
            recordingStateDidChange: { [weak self] state, _, _ in
                if state == .recording {
                    self?.applyBatteryLevel()
                }
            },
            streamingStateDidChange: { [weak self] state, _, _ in
                if state == .streaming {
                    self?.applyBatteryLevel()
                }
            })
    }

    override func didDisconnect() {
        streamSharingMonitor?.stop()
        batteryLevel  = nil
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlCommoneventstateUid {
            ArsdkFeatureSkyctrlCommoneventstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlSkycontrollerstateUid {
            ArsdkFeatureSkyctrlSkycontrollerstate.decode(command, callback: self)
        }
    }

    private func applyBatteryLevel() {
        guard let batteryLevel = batteryLevel else {
            return
        }
        streamSharingManager?.setControllerBatteryLevel(level: batteryLevel)
    }
}

// Called back when a command of the feature ArsdkFeatureSkyctrlCommoneventstateCallback is decoded.
extension SkyControllerStreamSharingOverlay: ArsdkFeatureSkyctrlCommoneventstateCallback {

    func onShutdown(reason: ArsdkFeatureSkyctrlCommoneventstateShutdownReason) {
        streamSharingManager?.finalizeRecord(reason: .peerShutdown)
    }
}

// Called back when a command of the feature ArsdkFeatureSkyctrlSkycontrollerstateCallback is decoded.
extension SkyControllerStreamSharingOverlay: ArsdkFeatureSkyctrlSkycontrollerstateCallback {

    func onBatteryChanged(percent: UInt) {
        batteryLevel = Int(percent)
        applyBatteryLevel()
    }
}
