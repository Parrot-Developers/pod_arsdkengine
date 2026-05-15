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

/// Controller for Anafi3 thermal control peripheral
class Anafi3ThermalController: ThermalControllerBase {

    private var arsdkDecoder: ArsdkThermalcontrolEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkThermalcontrolEventDecoder(listener: self)
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        arsdkDecoder.decode(command)
    }

    override func calibrate() -> Bool {
        let command = Arsdk_Thermalcontrol_Command.StartUniformityCalibration()
        return sendThermalControlCommand(.startCalibration(command))
    }

    override func abortCalibration() -> Bool {
        let command = Arsdk_Thermalcontrol_Command.AbortUniformityCalibration()
        return sendThermalControlCommand(.abortCalibration(command))
    }

    override func confirmUserAction() -> Bool {
        let command = Arsdk_Thermalcontrol_Command.ConfirmUniformityCalibrationUserAction()
        return sendThermalControlCommand(.userCalibration(command))
    }

    func sendThermalControlCommand(_ command: Arsdk_Thermalcontrol_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkThermalcontrolCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

// Extension for events processing.
extension Anafi3ThermalController: ArsdkThermalcontrolEventDecoderListener {
    func onDefaultCapabilities(_ defaultCapabilities: Arsdk_Thermalcontrol_Event.Capabilities) {
        let modes = Set(defaultCapabilities.powersavingModes.compactMap {
            ThermalPowerSavingMode(fromArsdk: $0)
        })
        thermalControl.update(supportedCalibrationMode: [.manual])
            .update(supportedPowerSavingModes: modes.isEmpty ? [.max] : modes)
            .notifyUpdated()
    }

    func onCalibrationState(_ calibrationState: Arsdk_Thermalcontrol_Event.UniformtiyCalibrationState) {
        thermalControl.update(calibrationState: CalibrationState(fromArsdk: calibrationState.step) ?? .unknown)
            .update(userActionRequired: calibrationState.requireUserAction)
            .notifyUpdated()
    }

    func onPowerSaving(_ powerSaving: Arsdk_Thermalcontrol_PowerSavingMode) {
        if let mode = ThermalPowerSavingMode(fromArsdk: powerSaving) {
            settingDidChange(.powerSavingMode(mode))
        }
    }
}
