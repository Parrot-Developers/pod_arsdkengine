// Copyright (C) 2024 Parrot Drones SAS
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

/// Anemometer component controller for Anafi messages based drone
class AnafiAnemometer: DeviceComponentController {

    /// Anemometer component
    private var anemometer: AnemometerCore!

    /// Decoder for flight data events.
    private var arsdkDecoder: ArsdkFlightdataEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkFlightdataEventDecoder(listener: self)
        anemometer = AnemometerCore(store: deviceController.device.instrumentStore)
    }

    override func willConnect() {
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        anemometer.update(northSpeed: nil)
                  .update(eastSpeed: nil)
                  .update(horizontalSpeed: nil)
                  .unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Extension for events processing.
extension AnafiAnemometer: ArsdkFlightdataEventDecoderListener {
    func onState(_ state: Arsdk_Flightdata_Event.State) {
        if state.hasDefaultCapabilities &&
            state.defaultCapabilities.supportedFeatures.contains(Arsdk_Flightdata_Features.windSpeedEstimation) {
            anemometer.publish()
        }
        if !state.isWindSpeedAvailable {
            anemometer.update(northSpeed: nil)
                      .update(eastSpeed: nil)
                      .update(horizontalSpeed: nil)
                      .notifyUpdated()
        }
    }

    func onWindSpeed(_ windSpeed: Arsdk_Flightdata_WindSpeed) {
        let northSpeed = Double(windSpeed.north)
        let eastSpeed = Double(windSpeed.east)
        let horizontalSpeed = sqrt(pow(northSpeed, 2) + pow(eastSpeed, 2))
        anemometer.update(northSpeed: northSpeed)
                  .update(eastSpeed: eastSpeed)
                  .update(horizontalSpeed: horizontalSpeed)
                  .notifyUpdated()
    }

    func onAirSpeed(_ airSpeed: Arsdk_Flightdata_AirSpeed) {
        // nothing to do
    }
}

/// Extension for methods to send anemometer commands.
extension AnafiAnemometer {
    /// Sends to the drone a anemometer command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand(_ command: Arsdk_Flightdata_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkFlightdataCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends get capabilities command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Flightdata_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendGetStateCommand(.getState(getState))
    }
}
