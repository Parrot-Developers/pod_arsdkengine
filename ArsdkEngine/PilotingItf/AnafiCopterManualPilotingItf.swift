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

/// Manual piloting interface component controller for the Anafi-messages piloting based copter products
class AnafiCopterManualPilotingItf: ManualCopterPilotingItfController {

    /// Drone flying state.
    private var flyingState: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState?

    /// Takeoff alarms on, `nil` if the command is never received.
    private var takeoffAlarmsOn: Set<ArsdkFeatureAlarmsTakeoffChecklistType>?
    /// Takeoff alarms on incoming.
    private var takeoffAlarmsOnTmp: Set<ArsdkFeatureAlarmsTakeoffChecklistType> = []

    /// Send takeoff command.
    override func sendTakeOffCommand() {
        if self.droneController.drone.model == .anafi2 ||
            self.droneController.drone.model == .anafi3 ||
            self.droneController.drone.model == .anafi3Usa {
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending smarttakeoffland command")
            sendCommand(ArsdkFeatureArdrone3Piloting.smartTakeOffLandEncoder())
        } else {
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending takeoff command")
            sendCommand(ArsdkFeatureArdrone3Piloting.takeOffEncoder())
        }
    }

    /// Send thrown takeoff command.
    override func sendThrownTakeOffCommand() {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending userTakeOffEncoder command")
        sendCommand(ArsdkFeatureArdrone3Piloting.userTakeOffEncoder(state: 1))
    }

    /// Send land command.
    override func sendLandCommand() {
        if self.droneController.drone.model == .anafi2 ||
            self.droneController.drone.model == .anafi3 ||
            self.droneController.drone.model == .anafi3Usa {
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending smarttakeoffland command")
            sendCommand(ArsdkFeatureArdrone3Piloting.smartTakeOffLandEncoder())
        } else {
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending land command")
            sendCommand(ArsdkFeatureArdrone3Piloting.landingEncoder())
        }
    }

    /// Send emergency cut-out command.
    override func sendEmergencyCutOutCommand() {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending emergency cut out command")
        sendCommand(ArsdkFeatureArdrone3Piloting.emergencyEncoder())
    }

    /// Send set max pitch/roll command.
    ///
    /// - Parameter value: new value
    override func sendMaxPitchRollCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max pitch/roll: \(value)")
        sendCommand(ArsdkFeatureArdrone3Pilotingsettings.maxTiltEncoder(current: Float(value)))
    }

    /// Send set max pitch/roll velocity command.
    ///
    /// - Parameter value: new value
    override func sendMaxPitchRollVelocityCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max pitch/roll velocity: \(value)")
        sendCommand(ArsdkFeatureArdrone3Speedsettings.maxPitchRollRotationSpeedEncoder(current: Float(value)))
    }

    /// Send set max vertical speed command.
    ///
    /// - Parameter value: new value
    override func sendMaxVerticalSpeedCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max vertical speed: \(value)")
        sendCommand(ArsdkFeatureArdrone3Speedsettings.maxVerticalSpeedEncoder(current: Float(value)))
    }

    /// Send set max yaw rotation speed command.
    ///
    /// - Parameter value: new value
    override func sendMaxYawRotationSpeedCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max yaw rotation speed: \(value)")
        sendCommand(ArsdkFeatureArdrone3Speedsettings.maxRotationSpeedEncoder(current: Float(value)))
    }

    /// Send set banked turn mode command.
    ///
    /// - Parameter value: new value
    override func sendBankedTurnModeCommand(_ value: Bool) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting banked turn mode: \(value)")
        sendCommand(ArsdkFeatureArdrone3Pilotingsettings.bankedTurnEncoder(value: value ? 1 : 0))
    }

    /// Send set Motion Detection command.
    ///
    /// - Parameter value: new value
    override func sendMotionDetectionModeCommand(_ value: Bool) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting Motion Detection mode: \(value)")
        sendCommand(ArsdkFeatureArdrone3Pilotingsettings.setMotionDetectionModeEncoder(enable: (value ? 1 : 0)))
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        let featureId = ArsdkCommand.getFeatureId(command)
        if featureId == kArsdkFeatureArdrone3PilotingstateUid {
            // Piloting State
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if featureId == kArsdkFeatureArdrone3PilotingsettingsstateUid {
            // Piloting Settings
            ArsdkFeatureArdrone3Pilotingsettingsstate.decode(command, callback: self)
        } else if featureId == kArsdkFeatureArdrone3SpeedsettingsstateUid {
            // Speed Settings
            ArsdkFeatureArdrone3Speedsettingsstate.decode(command, callback: self)
        } else if featureId == kArsdkFeatureAlarmsUid {
            ArsdkFeatureAlarms.decode(command, callback: self)
        }
    }

    /// Updates commands availabilities.
    private func updateAvailabilities() {
        guard let flyingState = flyingState else { return }

        switch flyingState {
        case .landed,
             .landing:

            let canTakeOff = takeoffAlarmsOn?.isEmpty ?? true
            manualCopterPilotingItf.update(canTakeOff: canTakeOff).update(canLand: false).notifyUpdated()
        case .takingoff,
             .hovering,
             .motorRamping,
             .usertakeoff,
             .flying:

            manualCopterPilotingItf.update(canTakeOff: false).update(smartWillThrownTakeoff: false)
                .update(canLand: true).notifyUpdated()
        case .emergency,
             .emergencyLanding:

            let canTakeOff = takeoffAlarmsOn?.isEmpty ?? false
            manualCopterPilotingItf.update(canTakeOff: canTakeOff).update(canLand: false).notifyUpdated()
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown flying state, skipping this event.")
            return
        }
    }
}

extension AnafiCopterManualPilotingItf: ArsdkFeatureAlarmsCallback {
    func onTakeoffChecklist(check: ArsdkFeatureAlarmsTakeoffChecklistType, state: ArsdkFeatureAlarmsState,
                            listFlagsBitField: UInt) {

        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            // No alarm on.
            takeoffAlarmsOn = []
            takeoffAlarmsOnTmp = []

            // Update availabilities.
            updateAvailabilities()
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                // Start receiving a new alarm list.
                takeoffAlarmsOnTmp = []
            }

            if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                // Remove from the list.
                takeoffAlarmsOnTmp.remove(check)
            } else {
                if state == .on {
                    // Add to the list.
                    takeoffAlarmsOnTmp.insert(check)
                } else {
                    // Remove from the list ; save only alarms on.
                    takeoffAlarmsOnTmp.remove(check)
                }
            }

            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                // End of list modiffication.
                takeoffAlarmsOn = takeoffAlarmsOnTmp

                // Update availabilities.
                updateAvailabilities()
            }
        }
    }
}

/// Piloting State callback implementation
extension AnafiCopterManualPilotingItf: ArsdkFeatureArdrone3PilotingstateCallback {
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        flyingState = state

        // Update availabilities.
        updateAvailabilities()
    }

    func onMotionState(state: ArsdkFeatureArdrone3PilotingstateMotionstateState) {
        switch state {
        case .steady:
            manualCopterPilotingItf.update(smartWillThrownTakeoff: false).notifyUpdated()
        case .moving:
            manualCopterPilotingItf.update(smartWillThrownTakeoff: true).notifyUpdated()
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown onMotion state, skipping this event.")
            return
        }
    }
}

/// Piloting Settings callback implementation
extension AnafiCopterManualPilotingItf: ArsdkFeatureArdrone3PilotingsettingsstateCallback {

    func onMaxTiltChanged(current: Float, min: Float, max: Float) {
        guard min <= max else {
            ULog.w(.tag, "Tilt bounds are not correct, skipping this event.")
            return
        }
        settingDidChange(.maxPitchRoll(Double(min), Double(current), Double(max)))
    }

    func onBankedTurnChanged(state: UInt) {
        settingDidChange(.bankedTurnMode(state == 1))
    }

    func onMotionDetection(enabled state: UInt) {
        settingDidChange(.motionDetectionMode(state == 1))
    }
}

/// Speed Settings callback implementation
extension AnafiCopterManualPilotingItf: ArsdkFeatureArdrone3SpeedsettingsstateCallback {
    func onMaxVerticalSpeedChanged(current: Float, min: Float, max: Float) {
        guard min <= max else {
            ULog.w(.tag, "Max vertical speed bounds are not correct, skipping this event.")
            return
        }
        settingDidChange(.maxVerticalSpeed(Double(min), Double(current), Double(max)))
    }

    func onMaxRotationSpeedChanged(current: Float, min: Float, max: Float) {
        guard min <= max else {
            ULog.w(.tag, "Max rotation speed bounds are not correct, skipping this event.")
            return
        }
        settingDidChange(.maxYawRotationSpeed(Double(min), Double(current), Double(max)))
    }

    func onMaxPitchRollRotationSpeedChanged(current: Float, min: Float, max: Float) {
        guard min <= max else {
            ULog.w(.tag, "Max pitch roll rotation speed bounds are not correct, skipping this event.")
            return
        }
        settingDidChange(.maxPitchRollVelocity(Double(min), Double(current), Double(max)))
    }
}
