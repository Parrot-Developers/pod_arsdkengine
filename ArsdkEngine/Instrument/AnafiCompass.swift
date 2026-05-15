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

/// Compass component controller for ArDrone3 messages based drones
class AnafiCompass: DeviceComponentController {

    /// Compass component
    private var compass: CompassCore!

    /// Decoder for backup link events.
    private var arsdkDecoder: ArsdkBackuplinkEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkBackuplinkEventDecoder(listener: self)
        compass = CompassCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        compass.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        compass.unpublish()
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        compass.publish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureArdrone3PilotingstateUid:
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            arsdkDecoder.decode(command)
        default:
            break
        }
    }
}

/// Anafi Piloting State decode callback implementation
extension AnafiCompass: ArsdkFeatureArdrone3PilotingstateCallback {
    func onAttitudeChanged(roll: Float, pitch: Float, yaw: Float) {
        compass.update(heading: Double(yaw).toBoundedDegrees()).notifyUpdated()
    }
}

/// Backup link decode callback implementation.
extension AnafiCompass: ArsdkBackuplinkEventDecoderListener {
    func onTelemetry(_ telemetry: Arsdk_Backuplink_Event.Telemetry) {
        compass.update(heading: Double(telemetry.heading).toBoundedDegrees()).notifyUpdated()
    }

    func onMainRadioDisconnecting(_ mainRadioDisconnecting: SwiftProtobuf.Google_Protobuf_Empty) {
        // nothing to do
    }
}
