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

/// Altimeter component controller for Anafi messages based drones
class AnafiAltimeter: DeviceComponentController {

    /// Altimeter component
    private var altimeter: AltimeterCore!

    /// Decoder for backup link events.
    private var arsdkDecoder: ArsdkBackuplinkEventDecoder!

    /// Decoder for navigation events.
    private var navigationDecoder: ArsdkNavigationEventDecoder!

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static var UnknownCoordinate: Double = 500

    /// Whether ArsdkNavigation messages are supported by the drone.
    private var arsdkNavigationSupported = false

    /// Whether altitude ATO in navigation message is supported by the drone.
    private var isAltitudeAtoInNavigationSupported = false

    /// Whether altitude AGL in navigation message is supported by the drone.
    private var isAltitudeAglInNavigationSupported = false

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkBackuplinkEventDecoder(listener: self)
        navigationDecoder = ArsdkNavigationEventDecoder(listener: self)
        altimeter = AltimeterCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        altimeter.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        altimeter.unpublish()
    }

    override func willConnect() {
        arsdkNavigationSupported = false
        isAltitudeAtoInNavigationSupported = false
        isAltitudeAglInNavigationSupported = false
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        altimeter.update(groundRelativeAltitude: nil)
            .update(absoluteAltitude: nil)
            .update(terrainData: nil)
            .update(verticalSpeed: nil)
            .publish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureArdrone3PilotingstateUid:
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        case kArsdkFeatureTerrainUid:
            ArsdkFeatureTerrain.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            arsdkDecoder.decode(command)
            navigationDecoder.decode(command)
        default:
            break
        }
    }
}

/// Anafi Piloting State decode callback implementation
extension AnafiAltimeter: ArsdkFeatureArdrone3PilotingstateCallback {
    func onAltitudeChanged(altitude: Double) {
        guard !isAltitudeAtoInNavigationSupported else { return }
        // this event informs about the altitude above take off
        altimeter.update(takeoffRelativeAltitude: altitude).notifyUpdated()
    }

    func onSpeedChanged(speedx: Float, speedy: Float, speedz: Float) {
        altimeter.update(verticalSpeed: Double(-speedz)).notifyUpdated()
    }

    func onPositionChanged(latitude: Double, longitude: Double, altitude: Double) {
        // nothing to do
    }

    func onGpsLocationChanged(latitude: Double, longitude: Double, altitude: Double,
                              latitudeAccuracy: Int, longitudeAccuracy: Int, altitudeAccuracy: Int) {
        guard !arsdkNavigationSupported else { return }
        if (latitude != AnafiAltimeter.UnknownCoordinate) && (longitude != AnafiAltimeter.UnknownCoordinate) {
            altimeter.update(absoluteAltitude: altitude).notifyUpdated()
        } else {
            altimeter.update(absoluteAltitude: nil).notifyUpdated()
        }
    }

    func onAltitudeAboveGroundChanged(altitude: Float) {
        guard !isAltitudeAglInNavigationSupported else { return }

        altimeter.update(groundRelativeAltitude: Double(altitude)).notifyUpdated()
    }
}

/// Anafi Terrain decode callback implementation
extension AnafiAltimeter: ArsdkFeatureTerrainCallback {
    func onAltitudeAboveTerrain(altitude: Int, type: ArsdkFeatureTerrainType, gridPrecision: Float) {
        switch type {
        case .none:
            altimeter.update(terrainData: nil)
        case .dted:
            altimeter.update(terrainData: TerrainDataCore(altitude: altitude, gridPrecision: Double(gridPrecision)))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown ArsdkFeatureTerrainType, skipping this event.")
            return
        }
        altimeter.notifyUpdated()
    }
}

/// Backup link decode callback implementation.
extension AnafiAltimeter: ArsdkBackuplinkEventDecoderListener {
    func onTelemetry(_ telemetry: Arsdk_Backuplink_Event.Telemetry) {
        altimeter.update(takeoffRelativeAltitude: Double(telemetry.altitudeAto)).notifyUpdated()
    }

    func onMainRadioDisconnecting(_ mainRadioDisconnecting: SwiftProtobuf.Google_Protobuf_Empty) {
        // nothing to do
    }
}

extension AnafiAltimeter: ArsdkNavigationEventDecoderListener {
    func onLocation(_ location: Arsdk_Navigation_Event.Location) {
        arsdkNavigationSupported = true

        if location.hasLatitude && location.hasLongitude && location.hasAltitudeAmsl {
            altimeter.update(absoluteAltitude: location.altitudeAmsl.value)
        } else {
            altimeter.update(absoluteAltitude: nil)
        }

        if location.hasAltitudeAto {
            isAltitudeAtoInNavigationSupported = true
            altimeter.update(takeoffRelativeAltitude: location.altitudeAto.value)
        }
        if location.hasAltitudeAgl {
            isAltitudeAglInNavigationSupported = true
            altimeter.update(groundRelativeAltitude: location.altitudeAgl.value)
        }
        altimeter.notifyUpdated()
    }

    func onState(_ state: Arsdk_Navigation_Event.State) {
        // nothing to do
    }

    func onRawGnssLocation(_ rawGnssLocation: Arsdk_Navigation_Event.RawGnssLocation) {
        // nothing to do
    }
}
