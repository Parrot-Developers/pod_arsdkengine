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

/// Alarms component controller for Anafi drones
class AnafiAlarms: DeviceComponentController {

    /// Alarms component
    private var alarms: AlarmsCore!
    /// Whether the drone uses battery alarms from the battery feature
    private var batteryFeatureSupported = false

    /// Automatic landing delay, in seconds, before below which the alarm is `.critical`
    private let autoLandingCriticalDelay = 3

    /// True or false if the drone is flying
    private var isFlying = false {
        didSet {
            if isFlying != oldValue {
                // Update the noGps tooDark and tooHigh alarms
                updateHoveringDifficulties()
            }
        }
    }

    /// Keeps the drone's Alarm for Hovering status (hoveringDifficultiesNoGpsTooDark and
    /// hoveringDifficultiesNoGpsTooDark)
    private var droneHoveringAlarmLevel = (tooDark: Alarm.Level.off, tooHigh: Alarm.Level.off)

    /// Disctionary of battery alarms.
    private var batteryAlarms: [Alarm.Kind: Alarm.Level] = [:]

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.alarms = AlarmsCore(store: deviceController.device.instrumentStore,
                                 supportedAlarms: [.threeMotorsFlight])
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        alarms.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        alarms.update(level: .off, forAlarm: .threeMotorsFlight)
        alarms.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3SettingsstateUid {
            ArsdkFeatureArdrone3Settingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureBatteryUid {
            ArsdkFeatureBattery.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonCommonstateUid {
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureControllerInfoUid {
            ArsdkFeatureControllerInfo.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureMotorsUid {
            ArsdkFeatureMotors.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureObstacleAvoidanceUid {
            ArsdkFeatureObstacleAvoidance.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureAlarmsUid {
            ArsdkFeatureAlarms.decode(command, callback: self)
        }
    }

    /// Update or reset alarms hoveringDifficultiesNoGpsTooDark and hoveringDifficultiesNoGpsTooHigh
    ///
    /// When the drone is not flying: theses alarms are always "off"
    ///
    /// When the drone is flying: the current drone alarm status is updated
    private func updateHoveringDifficulties() {
        if isFlying {
            alarms.update(level: droneHoveringAlarmLevel.tooDark, forAlarm: .hoveringDifficultiesNoGpsTooDark)
                .update(level: droneHoveringAlarmLevel.tooHigh, forAlarm: .hoveringDifficultiesNoGpsTooHigh)
                .notifyUpdated()
        } else {
            alarms.update(level: .off, forAlarm: .hoveringDifficultiesNoGpsTooDark)
                .update(level: .off, forAlarm: .hoveringDifficultiesNoGpsTooHigh)
                .notifyUpdated()
        }
    }
}

/// Anafi Piloting State decode callback implementation
extension AnafiAlarms: ArsdkFeatureArdrone3PilotingstateCallback {
    func onAlertStateChanged(state: ArsdkFeatureArdrone3PilotingstateAlertstatechangedState) {
        switch state {
        case .none:
            // remove all alarms linked to this command
            if !batteryFeatureSupported {
                alarms.update(level: .off, forAlarm: .power)
            }
            alarms.update(level: .off, forAlarm: .motorCutOut)
                .update(level: .off, forAlarm: .userEmergency)
                .update(level: .off, forAlarm: .magnetometerPertubation)
                .update(level: .off, forAlarm: .magnetometerLowEarthField)
                .update(level: .off, forAlarm: .inclinationTooHigh)
                .notifyUpdated()
        case .cutOut:
            // remove only non-persistent alarms
            alarms.update(level: .critical, forAlarm: .motorCutOut)
                .update(level: .off, forAlarm: .userEmergency)
                .update(level: .off, forAlarm: .magnetometerPertubation)
                .update(level: .off, forAlarm: .magnetometerLowEarthField)
                .update(level: .off, forAlarm: .inclinationTooHigh)
                .notifyUpdated()
        case .tooMuchAngle:
            // remove only non-persistent alarms
            alarms.update(level: .critical, forAlarm: .inclinationTooHigh)
                .update(level: .off, forAlarm: .motorCutOut)
                .update(level: .off, forAlarm: .userEmergency)
                .update(level: .off, forAlarm: .magnetometerPertubation)
                .update(level: .off, forAlarm: .magnetometerLowEarthField)
                .notifyUpdated()
        case .user:
            // remove only non-persistent alarms
            alarms.update(level: .off, forAlarm: .motorCutOut)
                .update(level: .critical, forAlarm: .userEmergency)
                .update(level: .off, forAlarm: .magnetometerPertubation)
                .update(level: .off, forAlarm: .magnetometerLowEarthField)
                .update(level: .off, forAlarm: .inclinationTooHigh)
                .notifyUpdated()
        case .criticalBattery, .almostEmptyBattery:
            if !batteryFeatureSupported {
                alarms.update(level: .critical, forAlarm: .power)
                    .update(level: .off, forAlarm: .motorCutOut)
                    .update(level: .off, forAlarm: .userEmergency)
                    .update(level: .off, forAlarm: .magnetometerPertubation)
                    .update(level: .off, forAlarm: .magnetometerLowEarthField)
                    .update(level: .off, forAlarm: .inclinationTooHigh)
                    .notifyUpdated()
            }
        case .lowBattery:
            if !batteryFeatureSupported {
                alarms.update(level: .warning, forAlarm: .power)
                    .update(level: .off, forAlarm: .motorCutOut)
                    .update(level: .off, forAlarm: .userEmergency)
                    .update(level: .off, forAlarm: .magnetometerPertubation)
                    .update(level: .off, forAlarm: .magnetometerLowEarthField)
                    .update(level: .off, forAlarm: .inclinationTooHigh)
                    .notifyUpdated()
            }
        case .magnetoPertubation:
            alarms.update(level: .critical, forAlarm: .magnetometerPertubation)
            alarms.update(level: .off, forAlarm: .magnetometerLowEarthField)
            .update(level: .off, forAlarm: .motorCutOut)
            .update(level: .off, forAlarm: .userEmergency)
            .update(level: .off, forAlarm: .inclinationTooHigh)
            .notifyUpdated()
        case .magnetoLowEarthField:
            alarms.update(level: .critical, forAlarm: .magnetometerLowEarthField)
            alarms.update(level: .off, forAlarm: .magnetometerPertubation)
            .update(level: .off, forAlarm: .motorCutOut)
            .update(level: .off, forAlarm: .userEmergency)
            .update(level: .off, forAlarm: .inclinationTooHigh)
            .notifyUpdated()
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown alert state, skipping this event.")
            return
        }
    }

    func onHoveringWarning(noGpsTooDark: UInt, noGpsTooHigh: UInt) {
        let tooDarkLevel: Alarm.Level = (noGpsTooDark == 0) ? .off : .warning
        let tooHighLevel: Alarm.Level = (noGpsTooHigh == 0) ? .off : .warning
        droneHoveringAlarmLevel = (tooDark: tooDarkLevel, tooHigh: tooHighLevel)
        updateHoveringDifficulties()
    }

    func onForcedLandingAutoTrigger(reason: ArsdkFeatureArdrone3PilotingstateForcedlandingautotriggerReason,
                                    delay: UInt) {

        switch reason {
        case .none:
            alarms.update(level: .off, forAlarm: .automaticLandingBatteryIssue).update(automaticLandingDelay: 0)
        case .batteryCriticalSoon:
            alarms.update(level: delay > autoLandingCriticalDelay ? .warning : .critical,
                          forAlarm: .automaticLandingBatteryIssue)
                .update(automaticLandingDelay: Double(delay))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            return
        }
        alarms.notifyUpdated()
    }

    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        switch state {
        case .hovering, .flying:
            isFlying = true
        default:
            isFlying = false
        }
    }

    func onWindStateChanged(state: ArsdkFeatureArdrone3PilotingstateWindstatechangedState) {
        let level: Alarm.Level
        switch state {
        case .ok:
            level = .off
        case .warning:
            level = .warning
        case .critical:
            level = .critical
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            return
        }
        alarms.update(level: level, forAlarm: .wind).notifyUpdated()
    }

    func onVibrationLevelChanged(state: ArsdkFeatureArdrone3PilotingstateVibrationlevelchangedState) {
        let level: Alarm.Level
        switch state {
        case .ok:
            level = .off
        case .critical:
            level = .critical
        case .warning:
           level = .warning
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            return
        }
        alarms.update(level: level, forAlarm: .strongVibrations).notifyUpdated()
    }

    func onHeadingLockedStateChanged(state: ArsdkFeatureArdrone3PilotingstateHeadinglockedstatechangedState) {
        let level: Alarm.Level
        switch state {
        case .ok:
            level = .off
        case .warning:
           level = .warning
        case .critical:
            level = .critical
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            return
        }
        alarms.update(level: level, forAlarm: .headingLock).notifyUpdated()
    }

    func onIcingLevelChanged(state: ArsdkFeatureArdrone3PilotingstateIcinglevelchangedState) {
        let level: Alarm.Level
        switch state {
        case .ok:
            level = .off
        case .warning:
            level = .warning
        case .critical:
            level = .critical
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            return
        }
        alarms.update(level: level, forAlarm: .icingLevel).notifyUpdated()
    }
}

/// Anafi Setting State decode callback implementation
extension AnafiAlarms: ArsdkFeatureArdrone3SettingsstateCallback {
    func onMotorErrorStateChanged(motorids: UInt,
                                  motorerror: ArsdkFeatureArdrone3SettingsstateMotorerrorstatechangedMotorerror) {
        alarms.update(level: (motorerror == .noerror) ? .off : .critical, forAlarm: .motorError).notifyUpdated()
    }
}

/// Battery feature decode callback implementation
extension AnafiAlarms: ArsdkFeatureBatteryCallback {
    func onAlert(alert: ArsdkFeatureBatteryAlert, level: ArsdkFeatureBatteryAlertLevel, listFlagsBitField: UInt) {

        /// Resets dictionary of battery alarms.
        func resetBatteryAlarms() {
            batteryAlarms[.power] = .off
            batteryAlarms[.batteryTooHot] = .off
            batteryAlarms[.batteryTooCold] = .off
            batteryAlarms[.batteryGaugeUpdateRequired] = .off
            batteryAlarms[.batteryAuthenticationFailure] = .off
        }

        /// Updates alarms component with battery alarms and notifies update.
        func updateBatteryAlarms() {
            for (alarm, level) in batteryAlarms {
                alarms.update(level: level, forAlarm: alarm)
            }
            alarms.notifyUpdated()
        }

        // declare that the drone supports the battery feature
        batteryFeatureSupported = true

        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            // remove all and notify
            resetBatteryAlarms()
            updateBatteryAlarms()
        } else {
            // first, reset battery alarms
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                resetBatteryAlarms()
            }

            let alarm: Alarm.Kind?
            switch alert {
            case .powerLevel:
                alarm = .power
            case .tooHot:
                alarm = .batteryTooHot
            case .tooCold:
                alarm = .batteryTooCold
            case .gaugeTooOld:
                alarm = .batteryGaugeUpdateRequired
            case .authenticationFailure:
                alarm = .batteryAuthenticationFailure
            case .sdkCoreUnknown:
                fallthrough
            @unknown default:
                alarm = nil
            }

            if let alarm = alarm {
                if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                    // remove
                    batteryAlarms[alarm] = .off
                } else {
                    let alarmLevel: Alarm.Level?
                    switch level {
                    case .none:
                        alarmLevel = .off
                    case .warning:
                        alarmLevel = .warning
                    case .critical:
                        alarmLevel = .critical
                    case .sdkCoreUnknown:
                        fallthrough
                    @unknown default:
                        alarmLevel = nil
                    }

                    if let alarmLevel = alarmLevel {
                        batteryAlarms[alarm] = alarmLevel
                    }
                }
            }
            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                // update and notify
                updateBatteryAlarms()
            }
        }
    }
}

/// Sensors state decode callback implementation
extension AnafiAlarms: ArsdkFeatureCommonCommonstateCallback {
    func onSensorsStatesListChanged(sensorname: ArsdkFeatureCommonCommonstateSensorsstateslistchangedSensorname,
                                    sensorstate: UInt) {
        let level: Alarm.Level
        switch sensorname {
        case .verticalCamera:
            level = sensorstate == 1 ? .off : .critical
            alarms.update(level: level, forAlarm: .verticalCamera).notifyUpdated()
        default:
            return
        }
    }
}

/// Contoller information decode callback implementation.
extension AnafiAlarms: ArsdkFeatureControllerInfoCallback {
    func onValidityFromDrone(isValid: UInt) {
        let level: Alarm.Level = isValid == 1 ? .off : .warning
        alarms.update(level: level, forAlarm: .unreliableControllerLocation)
            .notifyUpdated()
    }
}

extension AnafiAlarms: ArsdkFeatureMotorsCallback {
    func onThreeMotorsFlightStarted(id: ArsdkFeatureMotorsMotorId, reason: ArsdkFeatureMotorsThreeMotorsReason) {
        alarms.update(level: .critical, forAlarm: .threeMotorsFlight).notifyUpdated()
    }

    func onThreeMotorsFlightEnded() {
        alarms.update(level: .off, forAlarm: .threeMotorsFlight).notifyUpdated()
    }
}

extension AnafiAlarms: ArsdkFeatureObstacleAvoidanceCallback {
    func onAlerts(alertsBitField: UInt) {
        update(level: .warning, forAlarm: .highDeviation, ifAlert: .highDeviation, isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .droneStuck, ifAlert: .stuck, isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceDisabledStereoFailure, ifAlert: .stereoFailure,
               isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceDisabledStereoLensFailure, ifAlert: .stereoLensFailure,
               isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceDisabledGimbalFailure, ifAlert: .gimbalFailure,
               isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceDisabledTooDark, ifAlert: .tooDark,
               isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceDisabledEstimationUnreliable,
               ifAlert: .estimationUnreliable, isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceDisabledCalibrationFailure, ifAlert: .calibrationFailure,
               isSetIn: alertsBitField)
        update(level: .warning, forAlarm: .obstacleAvoidancePoorGps, ifAlert: .poorGps, isSetIn: alertsBitField)
        update(level: .warning, forAlarm: .obstacleAvoidanceStrongWind, ifAlert: .strongWind, isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceComputationalError, ifAlert: .computationalError,
               isSetIn: alertsBitField)
        update(level: .warning, forAlarm: .obstacleAvoidanceBlindMotionDirection, ifAlert: .blindMotionDirection,
               isSetIn: alertsBitField)
        update(level: .critical, forAlarm: .obstacleAvoidanceFreeze, ifAlert: .freeze,
               isSetIn: alertsBitField)
        alarms.notifyUpdated()
    }

    /// Sets the given alarm to the given level if the corresponding alert is set in the bitfield.
    ///
    /// - Parameters:
    ///    - level: the level of the alarm
    ///    - forAlarm: the kind of the alarm
    ///    - ifAlert: the alert to check
    ///    - isSetIn: the bitfield to check
    private func update(level: Alarm.Level, forAlarm kind: Alarm.Kind,
                        ifAlert alert: ArsdkFeatureObstacleAvoidanceAlert, isSetIn bitField: UInt) {
        let newLevel = ArsdkFeatureObstacleAvoidanceAlertBitField.isSet(alert, inBitField: bitField) ? level : .off
        alarms.update(level: newLevel, forAlarm: kind)
    }

    func onAlertTimer(alert: ArsdkFeatureObstacleAvoidanceAlert, timer: UInt) {
        var newAlert: Alarm.Kind?

        switch alert {
        case .highDeviation:
            newAlert = .highDeviation
        case .stuck:
            newAlert = .droneStuck
        case .stereoFailure:
            newAlert = .obstacleAvoidanceDisabledStereoFailure
        case .stereoLensFailure:
            newAlert = .obstacleAvoidanceDisabledStereoLensFailure
        case .gimbalFailure:
            newAlert = .obstacleAvoidanceDisabledGimbalFailure
        case .tooDark:
            newAlert = .obstacleAvoidanceDisabledTooDark
        case .estimationUnreliable:
            newAlert = .obstacleAvoidanceDisabledEstimationUnreliable
        case .calibrationFailure:
            newAlert = .obstacleAvoidanceDisabledCalibrationFailure
        case .poorGps:
            newAlert = .obstacleAvoidancePoorGps
        case .strongWind:
            newAlert = .obstacleAvoidanceStrongWind
        case .computationalError:
            newAlert = .obstacleAvoidanceComputationalError
        case .blindMotionDirection:
            newAlert = .obstacleAvoidanceBlindMotionDirection
        case .freeze:
            newAlert = .obstacleAvoidanceFreeze
        case .sdkCoreUnknown:
            break
        @unknown default:
            break
        }
        if let finalAlert = newAlert {
            alarms.update(timer: TimeInterval(timer), forAlarm: finalAlert).notifyUpdated()
        }
    }
}

extension AnafiAlarms: ArsdkFeatureAlarmsCallback {
    func onAlarms(type: ArsdkFeatureAlarmsType, state: ArsdkFeatureAlarmsState,
                  listFlagsBitField: UInt) {
        var newKind: Alarm.Kind?
        var newLevel: Alarm.Level?
        switch type {
        case .userEmergency:
            newKind = .userEmergency
        case .motorCutout:
            newKind = .motorCutOut
        case .droneInclinationTooHigh:
            newKind = .inclinationTooHigh
        case .magnetoPerturbation:
            newKind = .magnetometerPertubation
        case .magnetoLowEarthField:
            newKind = .magnetometerLowEarthField
        case .horizontalGeofenceReached:
            newKind = .horizontalGeofenceReached
        case .verticalGeofenceReached:
            newKind = .verticalGeofenceReached
        case .freefallDetected:
            newKind = .freeFallDetected
        case .fstcamDecalibrated:
            newKind = .stereoCameraDecalibrated
        case .sdkCoreUnknown:
            break
        @unknown default:
            break
        }

        switch state {
        case .off:
            newLevel = .off
        case .on:
            newLevel = .critical
        case .sdkCoreUnknown:
            break
        @unknown default:
            break
        }

        guard let kind = newKind, let level = newLevel else {
            return
        }

        if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
            resetAlarms()
            alarms.update(level: level, forAlarm: kind)
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            resetAlarms()
            alarms.notifyUpdated()
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
            alarms.update(level: .notAvailable, forAlarm: kind).notifyUpdated()
        } else {
            alarms.update(level: level, forAlarm: kind)
        }
        if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            alarms.notifyUpdated()
        }
    }

    func resetAlarms() {
        alarms.update(level: .notAvailable, forAlarm: .userEmergency)
        alarms.update(level: .notAvailable, forAlarm: .motorCutOut)
        alarms.update(level: .notAvailable, forAlarm: .inclinationTooHigh)

        alarms.update(level: .notAvailable, forAlarm: .magnetometerPertubation)
        alarms.update(level: .notAvailable, forAlarm: .magnetometerLowEarthField)
        alarms.update(level: .notAvailable, forAlarm: .horizontalGeofenceReached)
        alarms.update(level: .notAvailable, forAlarm: .verticalGeofenceReached)
        alarms.update(level: .notAvailable, forAlarm: .freeFallDetected)
        alarms.update(level: .notAvailable, forAlarm: .stereoCameraDecalibrated)
    }
}
