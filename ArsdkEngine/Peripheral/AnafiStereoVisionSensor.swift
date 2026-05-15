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

/// Base controller for Anafi stereo vision sensor peripheral
class AnafiStereoVisionSensor: DeviceComponentController {
    /// sensorId of main stereo vision sensor is always zero
    private static let sensorId = UInt(0)

    /// Stereo vision sensor component
    private var stereorVisionSensor: StereoVisionSensorCore!

    /// `true` if stereo vision sensor is supported by the drone.
    private var isSupported = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        stereorVisionSensor = StereoVisionSensorCore(store: deviceController.device.peripheralStore)
    }

    /// Drone is connected
    override func didConnect() {
        if isSupported {
            stereorVisionSensor.publish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        isSupported = false
        stereorVisionSensor.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureStereoVisionSensorUid {
            ArsdkFeatureStereoVisionSensor.decode(command, callback: self)
        }
    }
}

/// Anafi stereo vision sensor decode callback implementation
extension AnafiStereoVisionSensor: ArsdkFeatureStereoVisionSensorCallback {

    func onCapabilities(sensorId: UInt, model: ArsdkFeatureStereoVisionSensorModel, supportedFeaturesBitField: UInt) {
        if sensorId == AnafiStereoVisionSensor.sensorId {
            if ArsdkFeatureStereoVisionSensorFeatureBitField.isSet(.calibration,
                                                                   inBitField: supportedFeaturesBitField) {
                isSupported = true
            }
        } else {
            ULog.w(.stereovisionTag, """
                Calibration capabilities received for an
                unknown stereo vision sensor id=\(sensorId)
                """)
        }
    }

    func onCalibrationState(sensorId: UInt, state: ArsdkFeatureStereoVisionSensorCalibrationState) {

        if sensorId == AnafiStereoVisionSensor.sensorId {
            switch state {
            case .required:
                stereorVisionSensor.update(calibrated: false)
                    .notifyUpdated()
            case .ok:
                stereorVisionSensor.update(calibrated: true)
                    .notifyUpdated()
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                // don't change anything if value is unknown
                ULog.w(.tag, "Unknown state, skipping this calibration state event.")
            }
        } else {
            ULog.w(.stereovisionTag, "Calibration state received for an unknown stereo vision sensor id=\(sensorId)")
        }
    }
}
