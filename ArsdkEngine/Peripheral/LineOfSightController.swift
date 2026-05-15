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

/// LineOfSight component controller for LineOfSight feature message based drones
class LineOfSightController: DeviceComponentController {

    /// LineOfSight component
    var lineOfSight: LineOfSightCore!

    /// Is LineOfSight supported
    var supported: Bool = false

    /// Constructor
    ///
    /// - Parameters :
    ///     - deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        lineOfSight = LineOfSightCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        if supported {
            lineOfSight.publish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        lineOfSight.update(calibrationState: .required)
            .update(currentIssues: [])
        lineOfSight.unpublish()
        supported = false
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureTerrainUid {
            ArsdkFeatureTerrain.decode(command, callback: self)
        }
    }
}

/// LineOfSight backend implementation
extension LineOfSightController: LineOfSightBackend {
    func calibrate() {
        _ = sendCommand(ArsdkFeatureTerrain.calibrateEncoder())
    }

    func resetCalibration() {
        _ = sendCommand(ArsdkFeatureTerrain.calibrationResetEncoder())
    }
}

/// Terrain decode callback implementation
extension LineOfSightController: ArsdkFeatureTerrainCallback {

    func onCalibrationState(state: ArsdkFeatureTerrainCalibrationState, issueBitField: UInt) {
        supported = true

        if let gsdkState = LineOfSightCalibrationState(fromArsdk: state) {
            lineOfSight.update(calibrationState: gsdkState)
        }
        lineOfSight.update(currentIssues: LineOfSightCalibrationIssue.createSetFrom(bitField: issueBitField))
            .notifyUpdated()
    }

    func onCalibrateResult(result: ArsdkFeatureTerrainCalibrateResult, failureReasonBitField: UInt) {
        if let gsdkResult = LineOfSightCalibrationResult(fromArsdk: result) {
            lineOfSight.update(calibrationResult: gsdkResult)
        }
        lineOfSight.update(
            failureReasons: LineOfSightCalibrationFailureReason.createSetFrom(bitField: failureReasonBitField))
            .notifyUpdated()

        lineOfSight.update(calibrationResult: nil)
            .update(failureReasons: [])
            .notifyUpdated()
    }
}

// MARK: - Extensions
extension LineOfSightCalibrationIssue: ArsdkMappableEnum {
    static func createSetFrom(bitField: UInt) -> Set<LineOfSightCalibrationIssue> {
        var result = Set<LineOfSightCalibrationIssue>()
        ArsdkFeatureTerrainCalibrationIssueBitField.forAllSet(in: bitField) { arsdkValue in
            if let issue = LineOfSightCalibrationIssue(fromArsdk: arsdkValue) {
                result.insert(issue)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<LineOfSightCalibrationIssue, ArsdkFeatureTerrainCalibrationIssue>(
        [.tooClose: .tooClose, .tooLow: .tooLow, .invalidControllerCoords: .invalidControllerCoords,
         .badPitch: .badPitch])
}

extension LineOfSightCalibrationState: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<LineOfSightCalibrationState, ArsdkFeatureTerrainCalibrationState>(
        [.required: .required,
         .calibrated: .ok])
}

extension LineOfSightCalibrationResult: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<LineOfSightCalibrationResult, ArsdkFeatureTerrainCalibrateResult>(
        [.success: .success,
         .failure: .failure])
}

extension LineOfSightCalibrationFailureReason: ArsdkMappableEnum {
    static func createSetFrom(bitField: UInt) -> Set<LineOfSightCalibrationFailureReason> {
        var result = Set<LineOfSightCalibrationFailureReason>()
        ArsdkFeatureTerrainCalibrateResultReasonBitField.forAllSet(in: bitField) { arsdkValue in
            if let reason = LineOfSightCalibrationFailureReason(fromArsdk: arsdkValue) {
                result.insert(reason)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<LineOfSightCalibrationFailureReason, ArsdkFeatureTerrainCalibrateResultReason>(
        [.unmetPositionRequirements: .unmetPositionRequirements,
         .impreciseLocation: .impreciseLocation,
         .tooLargePitchOffset: .tooLargePitchOffset])
}
