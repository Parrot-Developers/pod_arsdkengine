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

/// Auto look at piloting interface component controller.
class AutoLookAtPilotingItf: ActivablePilotingItfController {

    /// The piloting interface from which this object is the delegate
    private var lookAtPilotingItf: LookAtPilotingItfCore {
        return pilotingItf as! LookAtPilotingItfCore
    }

    /// Mode requested in the pilotingItf
    private var lookAtMode: LookAtMode = .lookAt

    /// Set of supported modes for this piloting interface.
    private(set) var supportedModes: Set<LookAtMode> = []

    /// Local quality issues.
    private var _qualityIssues: [LookAtMode: Set<TrackingIssue>] = [:]

    /// Alerts about issues that currently hinder optimal behavior of this interface.
    public private(set) var qualityIssues =  [LookAtMode: Set<TrackingIssue>]() {
        didSet {
            if qualityIssues != oldValue {
                updateQualityIssues()
            }
        }
    }

    /// Local availability issues.
    private var _availabilityIssues: [LookAtMode: Set<TrackingIssue>] = [:]

    /// Reasons that preclude this piloting interface from being available at present.
    private var availabilityIssues = [LookAtMode: Set<TrackingIssue>]() {
         didSet {
            if availabilityIssues != oldValue {
                updateAvailabilityIssues()
                updateState()
            }
        }
    }

    /// Whether the Tracking Is Running (the interface should be .active)
    var trackingIsRunning = false {
        didSet {
            if trackingIsRunning != oldValue {
                updateState()
            }
        }
    }

    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController, sendsPilotingCommands: true)
        pilotingItf = LookAtPilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)
    }

    private func updateAvailabilityIssues() {
        if let availabilityIssues = availabilityIssues[lookAtMode] {
            lookAtPilotingItf.update(availabilityIssues: availabilityIssues)
        } else {
            lookAtPilotingItf.update(availabilityIssues: [])
        }
    }

    private func updateQualityIssues() {
        if let qualityIssues = qualityIssues[lookAtMode] {
            lookAtPilotingItf.update(qualityIssues: qualityIssues)
        } else {
            lookAtPilotingItf.update(qualityIssues: [])
        }
    }

    /// Updates the state of the piloting interface.
    private func updateState() {
        if supportedModes.isEmpty {
            notifyUnavailable()
        } else if trackingIsRunning {
            notifyActive()
        } else {
            if let issues = availabilityIssues[lookAtMode] {
                if issues.isEmpty {
                    notifyIdle()
                } else {
                    notifyUnavailable()
                }
            } else {
                notifyUnavailable()
            }
        }
    }

    override func didDisconnect() {
        super.didDisconnect()
        // the unavailable state will be set in unpublish
        lookAtPilotingItf.unpublish()
        supportedModes.removeAll()
    }

    override func didConnect() {
        if !supportedModes.isEmpty {
            lookAtPilotingItf.update(supportedLookAtModes: supportedModes)
            updateState()
            lookAtPilotingItf.publish()
        }
    }

    override func requestActivation() {
        sendStartLookAtCommand(mode: lookAtMode)
    }

    override func requestDeactivation() {
        sendStopLookAtCommand()
    }

    /// Start look at.
    func sendStartLookAtCommand(mode: LookAtMode) {
        switch mode {
        case .lookAt:
            sendCommand(ArsdkFeatureAutoLookAt.startEncoder(mode: .target))
        case .lookAtController:
            sendCommand(ArsdkFeatureAutoLookAt.startEncoder(mode: .pilot))
        }
    }

    /// Stop look at.
    func sendStopLookAtCommand() {
        sendCommand(ArsdkFeatureAutoLookAt.stopEncoder())
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureAutoLookAtUid {
            ArsdkFeatureAutoLookAt.decode(command, callback: self)
        }
    }
}

// MARK: - AutoLookAtPilotingItf
extension AutoLookAtPilotingItf: LookAtPilotingItfBackend {
    func set(lookAtMode newLookAtMode: LookAtMode) -> Bool {
        lookAtMode = newLookAtMode
        updateAvailabilityIssues()
        updateQualityIssues()
        var returnValue: Bool = false
        if pilotingItf.state == .active {
            // Change the lookAtModeStting (updating). It will be validated when the drone will change the mode.
            if lookAtPilotingItf.availabilityIssues.isEmpty {
                sendStartLookAtCommand(mode: newLookAtMode)
                returnValue = true
            } else {
                lookAtPilotingItf.update(lookAtMode: newLookAtMode)
                sendStopLookAtCommand()
            }
        } else {
            lookAtPilotingItf.update(lookAtMode: newLookAtMode)
        }
        updateState()
        return returnValue
    }

    func set(pitch: Int) {
        setPitch(pitch)
    }

    func set(roll: Int) {
        setRoll(roll)
    }

    func set(verticalSpeed: Int) {
        setGaz(verticalSpeed)
    }

    func activate() -> Bool {
        return droneController.pilotingItfActivationController.activate(pilotingItf: self)
    }
}

extension AutoLookAtPilotingItf: ArsdkFeatureAutoLookAtCallback {
    func onState(mode: ArsdkFeatureAutoLookAtMode, behavior: ArsdkFeatureAutoLookAtBehavior) {
        switch mode {
        case .target:
            lookAtMode = .lookAt
        case .pilot:
            lookAtMode = .lookAtController
        case .none:
            break
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown mode, skipping this event.")
            return
        }
        lookAtPilotingItf.update(lookAtMode: lookAtMode)
        updateAvailabilityIssues()
        updateQualityIssues()
        trackingIsRunning = behavior == .lookAt
        updateState()
    }

    func onInfo(mode: ArsdkFeatureAutoLookAtMode, missingInputsBitField: UInt, improvementsBitField: UInt,
                listFlagsBitField: UInt) {
        if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
            supportedModes.removeAll()
            _availabilityIssues.removeAll()
            _qualityIssues.removeAll()
        }
        var sdkMode: LookAtMode?
        switch mode {
        case .target:
            sdkMode = .lookAt
        case .pilot:
            sdkMode = .lookAtController
        case .none:
            break
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown mode, skipping this event.")
            return
        }
        if let sdkMode = sdkMode {
            supportedModes.insert(sdkMode)
            _availabilityIssues[sdkMode] = TrackingIssue.createSetFrom(bitField: missingInputsBitField)
            _qualityIssues[sdkMode] = TrackingIssue.createSetFrom(bitField: improvementsBitField)
        }
        if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            qualityIssues = _qualityIssues
            availabilityIssues = _availabilityIssues
            pilotingItf.notifyUpdated()
        }
    }
}

extension TrackingIssue: ArsdkMappableEnum {

    /// Create set of tracking issues from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all tracking issues set in bitField
    static func createSetFrom(bitField: UInt) -> Set<TrackingIssue> {
        var result = Set<TrackingIssue>()
        ArsdkFeatureAutoLookAtIndicatorBitField.forAllSet(in: bitField) { arsdkValue in
            if let missing = TrackingIssue(fromArsdk: arsdkValue) {
                result.insert(missing)
            }
        }
        return result
    }
    static var arsdkMapper = Mapper<TrackingIssue, ArsdkFeatureAutoLookAtIndicator>([
        .droneGpsInfoInaccurate: .droneGps,
        .droneNotCalibrated: .droneMagneto,
        .droneOutOfGeofence: .droneGeofence,
        .droneTooCloseToGround: .droneMinAltitude,
        .droneAboveMaxAltitude: .droneMaxAltitude,
        .droneNotFlying: .droneFlying,
        .targetGpsInfoInaccurate: .targetPositionAccuracy,
        .targetDetectionInfoMissing: .targetImageDetection,
        .droneTooCloseToTarget: .droneTargetDistanceMin,
        .droneTooFarFromTarget: .droneTargetDistanceMax,
        .targetHorizontalSpeedKO: .targetHorizSpeed,
        .targetVerticalSpeedKO: .targetVertSpeed,
        .targetAltitudeAccuracyKO: .targetAltitudeAccuracy
        ])
}
