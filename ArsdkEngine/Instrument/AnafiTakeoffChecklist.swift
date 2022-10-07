// Copyright (C) 2021 Parrot Drones SAS
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

/// Takeoff checklist component controller for Anafi drones
class AnafiTakeoffChecklist: DeviceComponentController {

    /// Takeoff checklist component
    private var takeoffChecklist: TakeoffChecklistCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        self.takeoffChecklist = TakeoffChecklistCore(store: deviceController.device.instrumentStore)
    }

    /// Drone is connected
    override func didConnect() {
        super.didConnect()
        takeoffChecklist.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        resetAlarms()
        takeoffChecklist.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
       if ArsdkCommand.getFeatureId(command) == kArsdkFeatureAlarmsUid {
            ArsdkFeatureAlarms.decode(command, callback: self)
        }
    }
}

/// Alarms callback implementation
extension AnafiTakeoffChecklist: ArsdkFeatureAlarmsCallback {

    func onTakeoffChecklist(check: ArsdkFeatureAlarmsTakeoffChecklistType, state: ArsdkFeatureAlarmsState,
                            listFlagsBitField: UInt) {
        var newKind: TakeoffAlarm.Kind?
        var newLevel: TakeoffAlarm.Level?

        switch check {
        case .baro:
            newKind = .baro
        case .batteryOldFw:
            newKind = .batteryGaugeUpdateRequired
        case .batteryIdentification:
            newKind = .batteryIdentification
        case .batteryCritical:
            newKind = .batteryLevel
        case .batteryLostComm:
            newKind = .batteryPoorConnection
        case .batteryIsTooCold:
            newKind = .batteryTooCold
        case .batteryIsTooHot:
            newKind = .batteryTooHot
        case .batteryIsConnected:
            newKind = .batteryUsbPortConnection
        case .cellularFlashing:
            newKind = .cellularModemFirmwareUpdate
        case .droneInclinationTooHigh:
            newKind = .droneInclination
        case  .gps:
            newKind = .gps
        case .gyro:
            newKind = .gyro
        case .magneto:
            newKind = .magneto
        case .magnetoCalibration:
            newKind = .magnetoCalibration
        case .ultrasound:
            newKind = .ultrasound
        case .updateOngoing:
            newKind = .updateOngoing
        case .vcam:
            newKind = .vcam
        case .verticalTof:
            newKind = .verticalTof
        case .sdkCoreUnknown:
            break
        @unknown default:
            break
        }

        switch state {
        case .off:
            newLevel = .off
        case .on:
            newLevel = .on
        case .sdkCoreUnknown:
            break
        @unknown default:
            break
        }

        guard let kind = newKind, let level = newLevel else {
            return
        }

        if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
            resetAlarms()
            takeoffChecklist.update(level: level, forAlarm: kind)
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            resetAlarms()
            takeoffChecklist.notifyUpdated()
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
            takeoffChecklist.update(level: .off, forAlarm: kind).notifyUpdated()
        } else {
            takeoffChecklist.update(level: level, forAlarm: kind)
        }
        if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            takeoffChecklist.notifyUpdated()
        }
    }

    func resetAlarms() {
        for kind in TakeoffAlarm.Kind.allCases {
            takeoffChecklist.update(level: .notAvailable, forAlarm: kind)
        }
    }
}
