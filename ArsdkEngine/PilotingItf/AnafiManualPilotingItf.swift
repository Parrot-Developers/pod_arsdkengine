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
import SwiftProtobuf

/// Manual piloting interface component controller for the Anafi-messages piloting based copter products
class AnafiManualPilotingItf: ManualCopterPilotingItfController {

    /// Drone flying state.
    private var flyingState: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState?

    /// Takeoff alarms on, `nil` if the command is never received.
    private var takeoffAlarmsOn: Set<ArsdkFeatureAlarmsTakeoffChecklistType>?
    /// Takeoff alarms on incoming.
    private var takeoffAlarmsOnTmp: Set<ArsdkFeatureAlarmsTakeoffChecklistType> = []

    /// Send takeoff command.
    override func sendTakeOffCommand() {
        switch self.droneController.drone.model {
        case .anafi2,
             .anafi3,
             .anafi3Mil,
             .anafi3Gov,
             .chuck3:
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending smarttakeoffland command")
            _ = sendCommand(ArsdkFeatureArdrone3Piloting.smartTakeOffLandEncoder())
        default:
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending takeoff command")
            _ = sendCommand(ArsdkFeatureArdrone3Piloting.takeOffEncoder())
        }
    }

    /// Send thrown takeoff command.
    override func sendThrownTakeOffCommand() {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending userTakeOffEncoder command")
        _ = sendCommand(ArsdkFeatureArdrone3Piloting.userTakeOffEncoder(state: 1))
    }

    /// Send land command.
    override func sendLandCommand() {
        switch self.droneController.drone.model {
        case .anafi2,
             .anafi3,
             .anafi3Mil,
             .anafi3Gov,
             .chuck3:
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending smarttakeoffland command")
            _ = sendCommand(ArsdkFeatureArdrone3Piloting.smartTakeOffLandEncoder())
        default:
            ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending land command")
            _ = sendCommand(ArsdkFeatureArdrone3Piloting.landingEncoder())
        }
    }

    /// Send emergency cut-out command.
    override func sendEmergencyCutOutCommand() {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: sending emergency cut out command")
        _ = sendCommand(ArsdkFeatureArdrone3Piloting.emergencyEncoder())
    }

    /// Send set max pitch/roll command.
    ///
    /// - Parameter value: new value
    override func sendMaxPitchRollCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max pitch/roll: \(value)")
        _ = sendCommand(ArsdkFeatureArdrone3Pilotingsettings.maxTiltEncoder(current: Float(value)))
    }

    /// Send set max horizontal speed.
    ///
    /// - Parameter value: new value
    override func sendMaxHorizontalSpeedCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max horizontal speed: \(value)")
        _ = sendCommand(ArsdkFeatureArdrone3Pilotingsettings.maxHorizontalSpeedEncoder(current: Float(value)))
    }

    /// Send set max pitch/roll velocity command.
    ///
    /// - Parameter value: new value
    override func sendMaxPitchRollVelocityCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max pitch/roll velocity: \(value)")
        _ = sendCommand(ArsdkFeatureArdrone3Speedsettings.maxPitchRollRotationSpeedEncoder(current: Float(value)))
    }

    /// Send set max vertical speed command.
    ///
    /// - Parameter value: new value
    override func sendMaxVerticalSpeedCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max vertical speed: \(value)")
        _ = sendCommand(ArsdkFeatureArdrone3Speedsettings.maxVerticalSpeedEncoder(current: Float(value)))
    }

    /// Send set max yaw rotation speed command.
    ///
    /// - Parameter value: new value
    override func sendMaxYawRotationSpeedCommand(_ value: Double) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting max yaw rotation speed: \(value)")
        _ = sendCommand(ArsdkFeatureArdrone3Speedsettings.maxRotationSpeedEncoder(current: Float(value)))
    }

    /// Send set banked turn mode command.
    ///
    /// - Parameter value: new value
    override func sendBankedTurnModeCommand(_ value: Bool) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting banked turn mode: \(value)")
        _ = sendCommand(ArsdkFeatureArdrone3Pilotingsettings.bankedTurnEncoder(value: value ? 1 : 0))
    }

    /// Send set Motion Detection command.
    ///
    /// - Parameter value: new value
    override func sendMotionDetectionModeCommand(_ value: Bool) {
        ULog.d(.ctrlTag, "AnafiCopter manual piloting: setting Motion Detection mode: \(value)")
        _ = sendCommand(ArsdkFeatureArdrone3Pilotingsettings.setMotionDetectionModeEncoder(enable: (value ? 1 : 0)))
    }

    override func sendSpeedModeCommand(_ value: SpeedMode) {
        var speedMode = Arsdk_Piloting_Command.SetSpeedMode()
        speedMode.speedMode = value.arsdkValue!
        _ = sendPilotingCommand(.setSpeedMode(speedMode))
    }

    override func sendTakeoffHoveringAltitude(_ value: Double) {
        var takeoffHoveringAltitude = Arsdk_Piloting_Command.SetTakeoffHoveringAltitude()
        takeoffHoveringAltitude.altitude = Float(value)
        _ = sendPilotingCommand(.setTakeoffHoveringAltitude(takeoffHoveringAltitude))
    }

    override func sendPreferredAttiModeCommand(_ value: Bool) {
        var preferredAttiMode = Arsdk_Piloting_AttiMode()
        preferredAttiMode.enabled = value
        _ = sendPilotingCommand(.setPreferredAttiMode(preferredAttiMode))
    }

    override func sendAssistanceModeCommand(_ value: AssistanceMode) -> Bool {
        var assistanceMode = Arsdk_Piloting_Command.SetAssistanceMode()
        assistanceMode.value = value.arsdkValue!
        return sendPilotingCommand(.setAssistanceMode(assistanceMode))
    }

    override func sendLoiterShapeCommand(_ value: LoiterShape) -> Bool {
        var shape = Arsdk_Loiter_Command.SetShape()
        shape.value = value.arsdkValue!
        return sendLoiterCommand(.setShape(shape))
    }

    override func sendLoiterDirectionCommand(_ value: LoiterDirection) -> Bool {
        var direction = Arsdk_Loiter_Command.SetDirection()
        direction.value = value.arsdkValue!
        return sendLoiterCommand(.setDirection(direction))
    }

    override func sendLoiterRadiusCommand(_ value: Double) -> Bool {
        var radius = Arsdk_Loiter_Command.SetRadius()
        radius.value = value
        return sendLoiterCommand(.setRadius(radius))
    }

    override func sendStartFlightModeCommand(_ value: Arsdk_Piloting_FlightMode) -> Bool {
        var startFlightMode = Arsdk_Piloting_Command.StartFlightMode()
        startFlightMode.value = value
        return sendPilotingCommand(.startFlightMode(startFlightMode))
    }

    /// A command has been received.
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        let featureId = ArsdkCommand.getFeatureId(command)
        switch featureId {
        case kArsdkFeatureArdrone3PilotingstateUid:
            // Piloting State
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        case kArsdkFeatureArdrone3PilotingsettingsstateUid:
            // Piloting Settings
            ArsdkFeatureArdrone3Pilotingsettingsstate.decode(command, callback: self)
        case kArsdkFeatureArdrone3SpeedsettingsstateUid:
            // Speed Settings
            ArsdkFeatureArdrone3Speedsettingsstate.decode(command, callback: self)
        case kArsdkFeatureAlarmsUid:
            ArsdkFeatureAlarms.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            arsdkPilotingDecoder.decode(command)
            arsdkLoiterDecoder.decode(command)
        default:
            break
        }
    }

    /// Updates commands availabilities.
    private func updateAvailabilities() {
        guard let flyingState = flyingState else { return }

        switch flyingState {
        case .landed:

            let canTakeOff = takeoffAlarmsOn?.isEmpty ?? true
            manualCopterPilotingItf.update(canTakeOff: canTakeOff).update(canLand: false).notifyUpdated()
        case .landing:

            manualCopterPilotingItf.update(canTakeOff: true).update(canLand: false).notifyUpdated()
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

extension AnafiManualPilotingItf: ArsdkFeatureAlarmsCallback {
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
extension AnafiManualPilotingItf: ArsdkFeatureArdrone3PilotingstateCallback {
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        flyingState = state

        // Update availabilities.
        updateAvailabilities()
    }

    func onMotionState(state: ArsdkFeatureArdrone3PilotingstateMotionstateState) {
        guard isHandLaunchSupported else { return }
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
extension AnafiManualPilotingItf: ArsdkFeatureArdrone3PilotingsettingsstateCallback {

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

    func onMaxHorizontalSpeedChanged(current: Float, min: Float, max: Float) {
        guard min <= max else {
            ULog.w(.tag, "Max horizontal speed bounds are not correct, skipping this event.")
            return
        }
        settingDidChange(.maxHorizontalSpeed(Double(min), Double(current), Double(max)))
    }

}

/// Speed Settings callback implementation
extension AnafiManualPilotingItf: ArsdkFeatureArdrone3SpeedsettingsstateCallback {
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

/// Piloting callback implementation
extension ManualCopterPilotingItfController: ArsdkPilotingEventDecoderListener {
    func onCapabilities(_ capabilities: Arsdk_Piloting_Event.Capabilities) {
        isHandLaunchSupported = capabilities.supportedFeatures.contains(.handLaunch)
        isPreferredAttiModeSupported = capabilities.supportedFeatures.contains(.attiMode)
        let assistanceModes = capabilities.assistanceModes.compactMap { AssistanceMode(fromArsdk: $0) }
        assistanceModeSetting?.handleNewAvailableValues(values: Set(assistanceModes))
        if !isHandLaunchSupported {
            manualCopterPilotingItf.update(smartWillThrownTakeoff: false)
        }
        if isPreferredAttiModeSupported {
            manualCopterPilotingItf.update(preferredAttiMode: false)
        }
        if capabilities.hasTakeoffHoveringAltitudeRange {
            manualCopterPilotingItf.update(takeoffHoveringAltitude: (
                min: Double(capabilities.takeoffHoveringAltitudeRange.min), value: nil,
                max: Double(capabilities.takeoffHoveringAltitudeRange.max)))
            manualPlanePilotingItf.update(takeoffHoveringAltitude: (
                min: Double(capabilities.takeoffHoveringAltitudeRange.min), value: nil,
                max: Double(capabilities.takeoffHoveringAltitudeRange.max)))
        }
        let speedModes  = capabilities.speedModes.compactMap { SpeedMode(fromArsdk: $0) }

        capabilitiesDidChange(.speedMode(Set(speedModes)))
    }

    func onState(_ state: Arsdk_Piloting_Event.State) {
        if state.hasSpeedMode, let speedMode = SpeedMode(fromArsdk: state.speedMode.value) {
            settingDidChange(.speedMode(speedMode))
        }

        if state.hasTakeoffHoveringAltitude, let setting = manualCopterPilotingItf.takeoffHoveringAltitude {
            settingDidChange(.takeoffHoveringAltitude(setting.min,
                                                      Double(state.takeoffHoveringAltitude.value),
                                                      setting.max))
        }

        if state.hasAssistanceMode,
           let assistanceMode = AssistanceMode(fromArsdk: state.assistanceMode.value) {
            assistanceModeSetting?.handleNewValue(value: assistanceMode)
        }

        if state.hasTakeoffState,
           let takeoffState = TakeoffState(fromArsdk: state.takeoffState.value) {
            manualPlanePilotingItf.update(takeoffState: takeoffState)
        }

        if isPreferredAttiModeSupported {
            if state.hasPreferredAttiMode {
                manualCopterPilotingItf.update(preferredAttiMode: state.preferredAttiMode.enabled)
            }

            if state.hasCurrentAttiMode {
                manualCopterPilotingItf.update(currentAttiMode: state.currentAttiMode.enabled)
            }
        }

        if state.hasVehicleMode {
            if let vehicleMode = VehicleMode(fromArsdk: state.vehicleMode.value) {
                self.vehicleMode = vehicleMode
            }
        }

        if state.hasVehicleType, let vehicleType = VehicleType(fromArsdk: state.vehicleType.value) {
            deviceStore?.write(key: SettingKey.vehicleTypeKey, value: vehicleType).commit()
            self.vehicleType = vehicleType
        }
        manualCopterPilotingItf.notifyUpdated()
        manualPlanePilotingItf.notifyUpdated()
    }
}

/// Plane callback implementation
extension ManualCopterPilotingItfController: ArsdkLoiterEventDecoderListener {

    func onState(_ state: Arsdk_Loiter_Event.State) {
        guard let manualPlanePilotingItf else { return }

        if state.hasDefaultCapabilities {
            let loiterShapes = state.defaultCapabilities.shapes.compactMap { LoiterShape(fromArsdk: $0) }
            loiterShapeSetting?.handleNewAvailableValues(values: Set(loiterShapes))

            let loiterDirections = state.defaultCapabilities.directions
                .compactMap { LoiterDirection(fromArsdk: $0) }
            loiterDirectionSetting?.handleNewAvailableValues(values: Set(loiterDirections))

            loiterRadiusSetting?.handleNewBounds(min: state.defaultCapabilities.radiusRange.min,
                                                 max: state.defaultCapabilities.radiusRange.max)
        }

        if state.hasShape,
           let loiterShape = LoiterShape(fromArsdk: state.shape.value) {
            loiterShapeSetting?.handleNewValue(value: loiterShape)
        }

        if state.hasDirection,
           let loiterDirection = LoiterDirection(fromArsdk: state.direction.value) {
            loiterDirectionSetting?.handleNewValue(value: loiterDirection)
        }
        if state.hasRadius {
            loiterRadiusSetting?.handleNewValue(value: state.radius.value)
        }

        manualPlanePilotingItf.notifyUpdated()
        deviceStore?.commit()
    }
}
