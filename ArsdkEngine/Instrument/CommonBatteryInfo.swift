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

/// Battery info component controller for Common messages based drones
class CommonBatteryInfo: DeviceComponentController {

    /// Battery info component
    private var batteryInfo: BatteryInfoCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.batteryInfo = BatteryInfoCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        batteryInfo.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        batteryInfo.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        let featureId = ArsdkCommand.getFeatureId(command)
        if featureId == kArsdkFeatureCommonCommonstateUid {
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        } else if featureId == kArsdkFeatureBatteryUid {
            ArsdkFeatureBattery.decode(command, callback: self)
        }
    }
}

/// Common common state decode callback implementation
extension CommonBatteryInfo: ArsdkFeatureCommonCommonstateCallback {
    func onBatteryStateChanged(percent: UInt) {
        batteryInfo.update(batteryLevel: Int(percent)).notifyUpdated()
    }
}

/// Feature battery decode callback implementation
extension CommonBatteryInfo: ArsdkFeatureBatteryCallback {
    func onHealth(stateOfHealth: UInt) {
        batteryInfo.update(batteryHealth: Int(stateOfHealth)).notifyUpdated()
    }

    func onCycleCount(count: UInt) {
        batteryInfo.update(cycleCount: Int(count)).notifyUpdated()
    }

    func onSerial(serial: String) {
        batteryInfo.update(serial: serial).notifyUpdated()
    }

    func onDescription(serial: String, date: String, design: UInt, cellCount: UInt,
                       cellMinVoltage: UInt, cellMaxVoltage: UInt) {
        batteryInfo
            .update(batteryDescription: BatteryDescription(date: DateFormatter.iso8601Base.date(from: date),
                                                           serial: serial,
                                                           cellCount: cellCount,
                                                           cellMinVoltage: cellMinVoltage,
                                                           cellMaxVoltage: cellMaxVoltage,
                                                           designCapacity: design))
            .notifyUpdated()
    }

    func onTemperature(temperature: UInt) {
        batteryInfo.update(temperature: temperature).notifyUpdated()
    }

    func onCapacity(fullCharge: UInt, remaining: UInt) {
        batteryInfo
            .update(capacity: BatteryCapacity(fullChargeCapacity: fullCharge,
                                              remainingCapacity: remaining))
            .notifyUpdated()
    }

    func onCellVoltage(index: UInt, cellVoltage: UInt) {
        batteryInfo.update(cellVoltage: cellVoltage, at: Int(index)).notifyUpdated()
    }

    func onVersion(hwRevision: UInt, fwVersion: String, gaugeVersion: String, usbVersion: String) {
        batteryInfo
            .update(version: BatteryVersion(hardwareRevision: hwRevision,
                                            firmwareVersion: fwVersion,
                                            gaugeVersion: gaugeVersion,
                                            usbVersion: usbVersion))
            .notifyUpdated()
    }
}
