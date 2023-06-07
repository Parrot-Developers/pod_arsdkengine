// Copyright (C) 2020 Parrot Drones SAS
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
import CoreLocation

/// Logger of device events.
class RCEventLogger: DeviceEventLogger {

    /// Device software version.
    private var softwareVersion: String?

    /// Device hardware version.
    private var hardwareVersion: String?

    /// Serial number high part.
    private var serialNumber: String?

    override public func didConnect() {
        if let softwareVersion = softwareVersion, let hardwareVersion = hardwareVersion,
            let serialNumber = serialNumber {
            eventLog.log("EVT:CONTROLLER;event='connected';" +
                "model_id='\(String(format: "%04x", device.deviceModel.internalId))';" +
                "sw_version='\(softwareVersion)';hw_version='\(hardwareVersion)'")
            eventLog.log("EVTS:CONTROLLER;serial='\(serialNumber)'")
        }
    }

    override public func didDisconnect() {
        eventLog.log("EVT:CONTROLLER;event='disconnected'")
    }

    override public func onCommandReceived(command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlSettingsstateUid {
            ArsdkFeatureSkyctrlSettingsstate.decode(command, callback: self)
        }
    }
}

/// Callbacks called when a command of the feature ArsdkFeatureSkyctrlSettingsstate is decoded.
extension RCEventLogger: ArsdkFeatureSkyctrlSettingsstateCallback {
    func onProductVersionChanged(software: String, hardware: String) {
        self.softwareVersion = software
        self.hardwareVersion = hardware
    }

    func onProductSerialChanged(serialnumber: String) {
        self.serialNumber = serialnumber
    }
}
