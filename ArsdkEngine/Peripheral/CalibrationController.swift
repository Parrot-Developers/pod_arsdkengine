// Copyright (C) 2026 Parrot Drones SAS
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

/// Base controller for calibration peripheral
class CalibrationController: DeviceComponentController {

    /// Calibration component
    private var calibration: CalibrationCore!

    /// Decoder for calibration controller events.
    private var arsdkDecoder: ArsdkCalibrationEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        calibration = CalibrationCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = ArsdkCalibrationEventDecoder(listener: self)
    }

    override func willConnect() {
        _ = sendGetStateCommand()
    }

    override func didDisconnect() {
        calibration.update(sensors: []).unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Calibration backend implementation.
extension CalibrationController: CalibrationBackend {
    func start(sensor: CalibrationSensorType) -> Bool {
        var command = Arsdk_Calibration_Command.Calibrate()
        command.sensor = sensor.arsdkValue!
        command.value = true
        return sendCalibrationCommand(.calibrate(command))
    }

    func abort(sensor: CalibrationSensorType) -> Bool {
        var command = Arsdk_Calibration_Command.Calibrate()
        command.sensor = sensor.arsdkValue!
        command.value = false
        return sendCalibrationCommand(.calibrate(command))
    }
}

/// Extension for events processing.
extension CalibrationController: ArsdkCalibrationEventDecoderListener {
    func onState(_ state: Arsdk_Calibration_Event.State) {
        if state.hasCalibrationStateList {
            let sensorStates: [CalibrationSensor] =
                state.calibrationStateList.calibrationState.compactMap {
                    if let sensor = CalibrationSensorType(fromArsdk: $0.sensor),
                       let status = SensorCalibrationState(fromArsdk: $0.status) {
                        return CalibrationSensor(type: sensor, state: status, isRequired: $0.isRequired)
                    } else {
                        return nil
                    }
                }
            calibration.update(sensors: sensorStates)
        }
        calibration.publish()
    }
}

/// Extension for methods to send Calibration commands.
extension CalibrationController {
    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Calibration_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendCalibrationCommand(.getState(getState))
    }

    /// Sends to the drone a state command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCalibrationCommand(_ command: Arsdk_Calibration_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkCalibrationCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension CalibrationSensorType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<CalibrationSensorType, Arsdk_Calibration_Sensor>([
        .pitot: .pitot
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension SensorCalibrationState: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<SensorCalibrationState, Arsdk_Calibration_Status>([
        .done: .done,
        .inProgress: .inProgress,
        .failed: .failed,
        .idle: .idle,
        .aborted: .aborted
    ])
}
