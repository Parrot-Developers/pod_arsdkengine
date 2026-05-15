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

/// Flying indicators component controller for Anafi messages based drones
class AnafiFlyingIndicators: DeviceComponentController {

    /// FlyingIndicator component
    private var flyingIndicator: FlyingIndicatorsCore!

    /// Decoder for backup link events.
    private var arsdkDecoder: ArsdkBackuplinkEventDecoder!

    /// Decoder for piloting events.
    public var arsdkPilotingDecoder: ArsdkPilotingEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkBackuplinkEventDecoder(listener: self)
        arsdkPilotingDecoder = ArsdkPilotingEventDecoder(listener: self)
        flyingIndicator = FlyingIndicatorsCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        flyingIndicator.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        flyingIndicator.update(vehicleMode: .copter).unpublish()
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        flyingIndicator.update(landedState: nil)
            .update(isHandLanding: nil)
            .publish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureArdrone3PilotingstateUid:
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        case kArsdkFeatureHandLandUid:
            ArsdkFeatureHandLand.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            arsdkDecoder.decode(command)
            arsdkPilotingDecoder.decode(command)
        default:
            break
        }
    }
}

/// Piloting State decode callback implementation
extension AnafiFlyingIndicators: ArsdkFeatureArdrone3PilotingstateCallback {
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        switch state {
        case .landed:
            flyingIndicator.update(landedState: .idle)
        case .takingoff:
            flyingIndicator.update(flyingState: .takingOff)
        case .hovering:
            flyingIndicator.update(flyingState: .waiting)
        case .flying:
            flyingIndicator.update(flyingState: .flying)
        case .landing:
            flyingIndicator.update(flyingState: .landing)
        case .emergency:
            flyingIndicator.update(state: .emergency)
        case .usertakeoff:
            flyingIndicator.update(landedState: .waitingUserAction)
        case .motorRamping:
            flyingIndicator.update(landedState: .motorRamping)
        case .emergencyLanding:
            flyingIndicator.update(state: .emergencyLanding)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown flying state, skipping this event.")
            return
        }
        flyingIndicator.notifyUpdated()
    }
}

/// Hand land callback implementation
extension AnafiFlyingIndicators: ArsdkFeatureHandLandCallback {
    func onState(state: ArsdkFeatureHandLandState) {
        switch state {
        case .idle:
            flyingIndicator.update(isHandLanding: false)
        case .ongoing:
            flyingIndicator.update(isHandLanding: true)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown hand land state, skipping this event.")
            return
        }
        flyingIndicator.notifyUpdated()
    }
}

/// Backup link decode callback implementation.
extension AnafiFlyingIndicators: ArsdkBackuplinkEventDecoderListener {
    func onTelemetry(_ telemetry: Arsdk_Backuplink_Event.Telemetry) {
        switch telemetry.flyingState {
        case .landed:
            flyingIndicator.update(state: .landed).notifyUpdated()
        case .hovering:
            flyingIndicator.update(flyingState: .waiting).notifyUpdated()
        case .flying, .rth, .flightPlan, .pointnfly:
            flyingIndicator.update(flyingState: .flying).notifyUpdated()
        case .emergency:
            flyingIndicator.update(state: .emergency).notifyUpdated()
        case .UNRECOGNIZED(_):
            ULog.w(.tag, "Unrecognized flying state, skipping this event.")
        }
    }

    func onMainRadioDisconnecting(_ mainRadioDisconnecting: SwiftProtobuf.Google_Protobuf_Empty) {
        // nothing to do
    }
}

/// Piloting callback implementation
extension AnafiFlyingIndicators: ArsdkPilotingEventDecoderListener {
    func onState(_ state: Arsdk_Piloting_Event.State) {
        if state.hasVehicleMode {
            if let vehicleMode = VehicleMode(fromArsdk: state.vehicleMode.value) {
                flyingIndicator.update(vehicleMode: vehicleMode).notifyUpdated()
            }
        }
    }

    func onCapabilities(_ capabilities: Arsdk_Piloting_Event.Capabilities) {
        // nothing to do
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension VehicleMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VehicleMode, Arsdk_Piloting_VehicleMode>([
        .copter: .copter,
        .plane: .plane
    ])
}
