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
import SwiftProtobuf

/// Point'n'fly piloting interface component controller for the Anafi message based drones.
class AnafiPointAndFlyPilotingItf: ActivablePilotingItfController {

    /// The piloting interface from which this object is the delegate.
    private var pointAndFlyPilotingItf: PointAndFlyPilotingItfCore {
        return pilotingItf as! PointAndFlyPilotingItfCore
    }

    /// Decoder for point'n'fly events.
    private var arsdkDecoder: ArsdkPointnflyEventDecoder!

    /// Pending point'n'fly directive.
    private var pendingDirective: PointAndFlyDirective?

    /// Constructor
    ///
    /// - Parameter activationController: activation controller that owns this piloting interface controller
    init(activationController: PilotingItfActivationController) {
        super.init(activationController: activationController, sendsPilotingCommands: true)
        arsdkDecoder = ArsdkPointnflyEventDecoder(listener: self)
        pilotingItf = PointAndFlyPilotingItfCore(store: droneController.drone.pilotingItfStore, backend: self)
    }

    override func willConnect() {
        super.willConnect()
        _ = sendGetStateCommand()
    }

    override func didConnect() {
        // Component will be published once state is received
    }

    override func didDisconnect() {
        super.didDisconnect()
        pilotingItf.unpublish()
        pendingDirective = nil
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }

    override func requestActivation() {
        if let directive = pendingDirective {
            _ = sendExecuteCommand(directive: directive)
            pendingDirective = nil
        }
    }

    override func requestDeactivation() {
        pendingDirective = nil
        _ = sendDeactivateCommand()
    }
}

/// Point'n'fly backend implementation.
extension AnafiPointAndFlyPilotingItf: PointAndFlyPilotingItfBackend {
    func execute(directive: PointAndFlyDirective) {
        if pilotingItf.state == .active {
            _ = sendExecuteCommand(directive: directive)
        } else {
            pendingDirective = directive
            _ = droneController.pilotingItfActivationController.activate(pilotingItf: self)
        }
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
}

/// Extension for methods to send point'n'fly commands.
extension AnafiPointAndFlyPilotingItf {
    /// Sends to the drone a point'n'fly command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendPointAndFlyCommand(_ command: Arsdk_Pointnfly_Command.OneOf_ID) -> Bool {
        var sent = false
        if let encoder = ArsdkPointnflyCommandEncoder.encoder(command) {
            sendCommand(encoder)
            sent = true
        }
        return sent
    }

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Pointnfly_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendPointAndFlyCommand(.getState(getState))
    }

    /// Sends deactivate command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendDeactivateCommand() -> Bool {
        return sendPointAndFlyCommand(.deactivate(Arsdk_Pointnfly_Command.Deactivate()))
    }

    /// Sends execute command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendExecuteCommand(directive: PointAndFlyDirective) -> Bool {
        var execute = Arsdk_Pointnfly_Command.Execute()
        switch directive {
        case let pointDirective as PointDirective:
            var point = Arsdk_Pointnfly_Point()
            point.latitude = pointDirective.latitude
            point.longitude = pointDirective.longitude
            point.altitude = pointDirective.altitude
            point.gimbalControlMode = pointDirective.gimbalControlMode.arsdkValue!
            execute.directive = Arsdk_Pointnfly_Command.Execute.OneOf_Directive.point(point)
        case let flyDirective as FlyDirective:
            var fly = Arsdk_Pointnfly_Fly()
            fly.latitude = flyDirective.latitude
            fly.longitude = flyDirective.longitude
            fly.altitude = flyDirective.altitude
            fly.gimbalControlMode = flyDirective.gimbalControlMode.arsdkValue!
            fly.maxHorizontalSpeed = flyDirective.horizontalSpeed
            fly.maxVerticalSpeed = flyDirective.verticalSpeed
            fly.maxYawRotationSpeed = flyDirective.yawRotationSpeed
            fly.heading = flyDirective.heading.arsdkValue
            execute.directive = Arsdk_Pointnfly_Command.Execute.OneOf_Directive.fly(fly)
        default:
            return false
        }

        return sendPointAndFlyCommand(.execute(execute))
    }
}

/// Extension for events processing.
extension AnafiPointAndFlyPilotingItf: ArsdkPointnflyEventDecoderListener {
    func onState(_ state: Arsdk_Pointnfly_Event.State) {
        if let state = state.state {
            switch state {
            case .unavailable(let unavailable):
                let issues = Set(unavailable.reasons.compactMap { PointAndFlyIssue(fromArsdk: $0) })
                pointAndFlyPilotingItf.update(unavailabilityReasons: issues)
                    .update(currentDirective: nil)
                notifyUnavailable()
            case .idle:
                pointAndFlyPilotingItf.update(unavailabilityReasons: [])
                    .update(currentDirective: nil)
                notifyIdle()
            case .active(let active):
                if let directive = active.currentDirective {
                    switch directive {
                    case .point(let point):
                        if let mode = PointAndFlyGimbalControlMode(fromArsdk: point.gimbalControlMode) {
                            let pointDirective = PointDirective(latitude: point.latitude, longitude: point.longitude,
                                                                altitude: point.altitude, gimbalControlMode: mode)
                            pointAndFlyPilotingItf.update(unavailabilityReasons: [])
                                .update(currentDirective: pointDirective)
                            notifyActive()
                        }
                    case .fly(let fly):
                        if let mode = PointAndFlyGimbalControlMode(fromArsdk: fly.gimbalControlMode),
                           let heading = PointAndFlyHeading(fromArsdk: fly.heading) {
                            let flyDirective = FlyDirective(latitude: fly.latitude, longitude: fly.longitude,
                                                            altitude: fly.altitude, gimbalControlMode: mode,
                                                            horizontalSpeed: fly.maxHorizontalSpeed,
                                                            verticalSpeed: fly.maxVerticalSpeed,
                                                            yawRotationSpeed: fly.maxYawRotationSpeed, heading: heading)
                            pointAndFlyPilotingItf.update(unavailabilityReasons: [])
                                .update(currentDirective: flyDirective)
                            notifyActive()
                        }
                    }
                }
            }
        }

        pointAndFlyPilotingItf.publish()
    }

    func onExecution(_ execution: Arsdk_Pointnfly_ExecutionStatus) {
        pointAndFlyPilotingItf.update(executionStatus: PointAndFlyExecutionStatus(fromArsdk: execution)).notifyUpdated()
        pointAndFlyPilotingItf.update(executionStatus: nil).notifyUpdated()
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension PointAndFlyGimbalControlMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<PointAndFlyGimbalControlMode, Arsdk_Pointnfly_GimbalControlMode>([
        .locked: .locked,
        .lockedOnce: .lockedOnce,
        .free: .free])
}

/// Extension that adds conversion from/to arsdk enum.
extension PointAndFlyIssue: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<PointAndFlyIssue, Arsdk_Pointnfly_UnavailabilityReason>([
        .droneNotCalibrated: .droneNotCalibrated,
        .droneGpsInfoInaccurate: .droneGpsInfoInaccurate,
        .droneOutOfGeofence: .droneOutGeofence,
        .droneTooCloseToGround: .droneTooCloseToGround,
        .droneAboveMaxAltitude: .droneAboveMaxAltitude,
        .insufficientBattery: .droneInsufficientBattery
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension PointAndFlyExecutionStatus: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<PointAndFlyExecutionStatus, Arsdk_Pointnfly_ExecutionStatus>([
        .success: .success,
        .failed: .failed,
        .interrupted: .interrupted
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension PointAndFlyHeading {
    /// Arsdk value corresponding to the enum value.
    var arsdkValue: Arsdk_Pointnfly_Fly.OneOf_Heading {
        switch self {
        case .current:
            return .current(Google_Protobuf_Empty())
        case .toTargetBefore:
            return .toTargetBefore(Google_Protobuf_Empty())
        case .customBefore(let heading):
            return .customBefore(heading)
        case .customDuring(let heading):
            return .customDuring(heading)
        }
    }

    /// Creates an enum from an arsdk enum value.
    ///
    /// - Parameter arsdkValue: arsdk enum value
    init?(fromArsdk arsdkValue: Arsdk_Pointnfly_Fly.OneOf_Heading?) {
        guard let arsdkValue = arsdkValue else {
            return nil
        }

        switch arsdkValue {
        case .current:
            self = .current
        case .toTargetBefore:
            self = .toTargetBefore
        case .customBefore(let heading):
            self = .customBefore(heading)
        case .customDuring(let heading):
            self = .customDuring(heading)
        }
    }
}
