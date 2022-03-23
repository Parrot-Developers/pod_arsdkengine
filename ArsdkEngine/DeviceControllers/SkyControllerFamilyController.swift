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

/// RC controller for the SkyController3 controller.
class SkyControllerFamilyController: RCController {

    override init(engine: ArsdkEngine, deviceUid: String, model: RemoteControl.Model, name: String) {
        super.init(engine: engine, deviceUid: deviceUid, model: model, name: name)

        let useFtp = model == .skyCtrl3

        // Instruments
        componentControllers.append(SkyControllerBatteryInfo(deviceController: self))
        componentControllers.append(SkyControllerCompass(deviceController: self))
        componentControllers.append(CellularLinkStatusController(deviceController: self))
        if model == .skyCtrl4 {
            componentControllers.append(CellularLogsController(deviceController: self))
        }

        // Peripherals
        componentControllers.append(DroneManagerDroneFinder(proxyDeviceController: self))
        switch model {
        case .skyCtrl4:
            componentControllers.append(Sc4Gamepad(deviceController: self))
        case .skyCtrl3, .skyCtrlUA:
            componentControllers.append(Sc3Gamepad(deviceController: self))
        }

        componentControllers.append(SkyControllerSystemInfo(deviceController: self))
        if let firmwareStore = engine.utilities.getUtility(Utilities.firmwareStore),
            let firmwareDownloader = engine.utilities.getUtility(Utilities.firmwareDownloader) {
            componentControllers.append(
                UpdaterController(deviceController: self,
                                  config: UpdaterController.Config(deviceModel: deviceModel,
                                                                   uploaderType: useFtp ? .ftp : .http),
                                  firmwareStore: firmwareStore, firmwareDownloader: firmwareDownloader))
        }
        if let flightLogStorage = engine.utilities.getUtility(Utilities.flightLogStorage) {
            componentControllers.append(
                useFtp ?
                    FtpFlightLogDownloader(deviceController: self, flightLogStorage: flightLogStorage) :
                    HttpFlightLogDownloader(deviceController: self, flightLogStorage: flightLogStorage))
        }
        if let crashReportStorage = engine.utilities.getUtility(Utilities.crashReportStorage) {
            componentControllers.append(
                useFtp ?
                    FtpCrashmlDownloader(deviceController: self, crashReportStorage: crashReportStorage) :
                    HttpCrashmlDownloader(deviceController: self, crashReportStorage: crashReportStorage))
        }
        componentControllers.append(SkyControllerMagnetometer(deviceController: self))
        componentControllers.append(SkyControllerCopilot(deviceController: self))
        componentControllers.append(SkyControllerRadioControl(deviceController: self))
        if model == .skyCtrlUA {
            componentControllers.append(MicrohardController(deviceController: self))
        }
        sendDateAndTime = { [weak self] in
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = NSTimeZone.system
            dateFormatter.locale = NSLocale.system
            let currentDate = Date()

            // send date/time
            dateFormatter.dateFormat = "yyyyMMdd'T'HHmmssZZZ"
            let currentDateStr = dateFormatter.string(from: currentDate)
            self?.sendCommand(ArsdkFeatureSkyctrlCommon.currentDateTimeEncoder(datetime: currentDateStr))

            if let eventLogger = self?.engine.utilities.getUtility(Utilities.eventLogger) {
                eventLogger.log("EVT:SEND_TIME_CTRL;time='\(currentDateStr)'")
            }
        }
    }
}
