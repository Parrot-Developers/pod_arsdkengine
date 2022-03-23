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

/// Gimbal component controller for Gimbal feature message based drones
class GimbalFeatureCalibratableGimbal: DeviceComponentController, ArsdkFeatureGimbalCallback {

    /// Gimbal id of gimbal
    public var gimbalId: UInt?

    /// Gimbal component
    var gimbal: CalibratableGimbalCore!

    /// Gimbal model
    var model: ArsdkFeatureGimbalModel!

    /// Is gimbal supported
    var supported: Bool = false

    /// Constructor
    ///
    /// - Parameters :
    ///     - deviceController: device controller owning this component controller (weak)
    ///     - model: the model of the gimbal
    init(deviceController: DeviceController, model: ArsdkFeatureGimbalModel) {
        super.init(deviceController: deviceController)
        self.model = model
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        if supported {
            gimbal.publish()
        } else {
            gimbal.unpublish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        gimbal.update(currentErrors: [])
        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            gimbal.unpublish()
        }
        gimbal.update(calibrationProcessState: .none)
        gimbal.notifyUpdated()
        supported = false
    }

    /// Drone is about to be forgotten
    override func willForget() {
        gimbal.unpublish()
        super.willForget()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGimbalUid {
            ArsdkFeatureGimbal.decode(command, callback: self)
        }
    }
}

/// Gimbal backend implementation
extension GimbalFeatureCalibratableGimbal: CalibratableGimbalBackend {
    func startCalibration() {
        guard let gimbalId = gimbalId else {
            ULog.e(.gimbalTag, "Can't start calibration: gimbal ID undefined")
            return
        }
        sendCommand(ArsdkFeatureGimbal.calibrateEncoder(gimbalId: gimbalId))
    }

    func cancelCalibration() {
        guard let gimbalId = gimbalId else {
            ULog.e(.gimbalTag, "Can't cancel calibration: gimbal ID undefined")
            return
        }
        sendCommand(ArsdkFeatureGimbal.cancelCalibrationEncoder(gimbalId: gimbalId))
    }
}

/// Gimbal decode callback implementation
extension GimbalFeatureCalibratableGimbal {

    func onGimbalCapabilities(gimbalId: UInt, model: ArsdkFeatureGimbalModel, axesBitField: UInt) {
        if model == self.model {
            self.gimbalId = gimbalId
            supported = true
        }
    }

    @objc(onCalibrationState:gimbalId:) func onCalibrationState(state: ArsdkFeatureGimbalCalibrationState,
                                                                gimbalId: UInt) {
        if gimbalId == self.gimbalId {
            switch state {
            case .ok:
                gimbal.update(calibrated: true).notifyUpdated()
            case .required:
                gimbal.update(calibrated: false).notifyUpdated()
            case .inProgress:
                gimbal.update(calibrationProcessState: .calibrating).notifyUpdated()
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                // don't change anything if value is unknown
                ULog.w(.tag, "Unknown state, skipping this calibration state event.")
            }
        } else {
            ULog.w(.gimbalTag, "Calibration state received for an unknown gimbal id=\(gimbalId)")
        }
    }

    @objc(onCalibrationResult:result:) func onCalibrationResult(gimbalId: UInt,
                                                                result: ArsdkFeatureGimbalCalibrationResult) {
        if gimbalId == self.gimbalId {
            switch result {
            case .success:
                gimbal.update(calibrationProcessState: .success).notifyUpdated()
            case .failure:
                gimbal.update(calibrationProcessState: .failure).notifyUpdated()
            case .canceled:
                gimbal.update(calibrationProcessState: .canceled).notifyUpdated()
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                // don't change anything if value is unknown
                ULog.w(.tag, "Unknown state, skipping this calibration result event.")
                return
            }
            //             success, failure and canceled status are transient, reset calibration process state to none
            gimbal.update(calibrationProcessState: .none).notifyUpdated()
        } else {
            ULog.w(.gimbalTag, "Calibration result received for an unknown gimbal id=\(gimbalId)")
        }
    }

    @objc(onAlert:errorBitField:) func onAlert(gimbalId: UInt, errorBitField: UInt) {
        if gimbalId == self.gimbalId {
            gimbal.update(currentErrors: GimbalError.createSetFrom(bitField: errorBitField)).notifyUpdated()
        } else {
            ULog.w(.gimbalTag, "Alerts received for an unknown gimbal id=\(gimbalId)")
        }
    }
}

// MARK: - Extensions
extension GimbalError: ArsdkMappableEnum {
    static func createSetFrom(bitField: UInt) -> Set<GimbalError> {
        var result = Set<GimbalError>()
        ArsdkFeatureGimbalErrorBitField.forAllSet(in: bitField) { arsdkValue in
            if let axis = GimbalError(fromArsdk: arsdkValue) {
                result.insert(axis)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<GimbalError, ArsdkFeatureGimbalError>(
        [.calibration: .calibrationError, .overload: .overloadError, .communication: .commError,
         .critical: .criticalError])
}
