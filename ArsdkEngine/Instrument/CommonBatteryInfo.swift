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

/// Battery info component controller for Common messages based drones
class CommonBatteryInfo: DeviceComponentController {

    /// Battery info component
    private var batteryInfo: BatteryInfoCore!

    /// Decoder for backup link events.
    private var arsdkDecoder: ArsdkBackuplinkEventDecoder!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkBackuplinkEventDecoder(listener: self)
        batteryInfo = BatteryInfoCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        batteryInfo.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        batteryInfo.update(isChargeLevelReliable: nil)
        batteryInfo.update(cellConfiguration: nil)
        batteryInfo.unpublish()
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        // Keep published. Battery charge/level is provided by backup telemetry.
        // However, properly clear info we cannot provide reliably.
        batteryInfo.update(batteryHealth: nil)
            .update(cycleCount: nil)
            .update(temperature: nil)
            .update(capacity: nil)
            .update(cellVoltages: nil)
            .publish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureCommonCommonstateUid:
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        case kArsdkFeatureCommonChargerstateUid:
            ArsdkFeatureCommonChargerstate.decode(command, callback: self)
        case kArsdkFeatureBatteryUid:
            ArsdkFeatureBattery.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            arsdkDecoder.decode(command)
        default:
            break
        }
    }
}

/// Common common state decode callback implementation
extension CommonBatteryInfo: ArsdkFeatureCommonCommonstateCallback {
    func onBatteryStateChanged(percent: UInt) {
        batteryInfo.update(batteryLevel: Int(percent)).notifyUpdated()
    }
}

/// Common charger state decode callback implementation
extension CommonBatteryInfo: ArsdkFeatureCommonChargerstateCallback {
    func onChargingInfo(phase: ArsdkFeatureCommonChargerstateCharginginfoPhase,
                        rate: ArsdkFeatureCommonChargerstateCharginginfoRate,
                        intensity: UInt, fullchargingtime: UInt) {
        switch phase {
        case .constantCurrent1, .constantCurrent2, .constantVoltage:
            batteryInfo.update(isCharging: true)
        default:
            batteryInfo.update(isCharging: false)
        }
        batteryInfo.notifyUpdated()
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

    func onReliability(isChargeLevelReliable: UInt) {
        batteryInfo.update(isChargeLevelReliable: isChargeLevelReliable == 1).notifyUpdated()
    }

    func onCellConfig(config: String, series: UInt, parallel: UInt) {
        batteryInfo.update(cellConfiguration: BatteryCellConfiguration(config: config, series: series,
                                                                       parallel: parallel)).notifyUpdated()
    }
}

/// Backup link decode callback implementation.
extension CommonBatteryInfo: ArsdkBackuplinkEventDecoderListener {
    func onTelemetry(_ telemetry: Arsdk_Backuplink_Event.Telemetry) {
        batteryInfo.update(batteryLevel: Int(telemetry.batteryCharge)).notifyUpdated()
    }

    func onMainRadioDisconnecting(_ mainRadioDisconnecting: SwiftProtobuf.Google_Protobuf_Empty) {
        // nothing to do
    }
}
