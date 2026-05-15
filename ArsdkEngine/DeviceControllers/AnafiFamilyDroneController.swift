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

/// Anafi specific drone controller
class AnafiFamilyDroneController: DroneController {

    /// Shared last known state of the tracking function at the drone level
    private let trackingSharing = FollowFeatureTrackingSharing()

    /// Constructor
    ///
    /// - Parameters:
    ///    - engine: arsdk engine instance
    ///    - deviceUid: device uid
    ///    - name: drone name
    ///    - model: drone model
    init(engine: ArsdkEngine, deviceUid: String, name: String, model: Drone.Model) {
        super.init(engine: engine, deviceUid: deviceUid, model: model, name: name,
                   pcmdEncoder: PilotingCommand.Encoder.AnafiCopter(),
                   ephemerisConfig: EphemerisConfig(fileType: .ublox, uploader: HttpEphemerisUploader()),
                   defaultPilotingItfFactory: { activationController in
            return AnafiManualPilotingItf(activationController: activationController)
        })
        // add all component controllers
        // Activable Piloting Itfs
        componentControllers.append(pilotingItfActivationController.defaultPilotingItf)
        componentControllers.append(AnafiReturnHomePilotingItf(
            activationController: pilotingItfActivationController))
        componentControllers.append(HttpFlightPlanPilotingItfController(
            activationController: pilotingItfActivationController))
        componentControllers.append(AnafiGuidedPilotingItf(
            activationController: pilotingItfActivationController))
        componentControllers.append(AnafiPoiPilotingItf(
            activationController: pilotingItfActivationController))
        componentControllers.append(AnafiPointAndFlyPilotingItf(
            activationController: pilotingItfActivationController))

        componentControllers.append(AutoLookAtPilotingItf(
            activationController: pilotingItfActivationController))
        componentControllers.append(FollowFeatureLookAtPilotingItf(
            activationController: pilotingItfActivationController, trackingSharing: trackingSharing))
        componentControllers.append(FollowFeatureFollowMePilotingItf(
            activationController: pilotingItfActivationController, trackingSharing: trackingSharing))

        // Not activable piloting Itfs
        componentControllers.append(AnimFeaturePilotingItfController(
            activationController: pilotingItfActivationController))
        // Instruments
        componentControllers.append(AnafiFlyingIndicators(deviceController: self))
        componentControllers.append(AnafiAlarms(deviceController: self))
        componentControllers.append(AnafiGps(deviceController: self))
        componentControllers.append(AnafiCompass(deviceController: self))
        componentControllers.append(AnafiAltimeter(deviceController: self))
        componentControllers.append(AnafiSpeedometer(deviceController: self))
        componentControllers.append(AnafiAttitudeIndicator(deviceController: self))
        componentControllers.append(CommonRadio(deviceController: self))
        componentControllers.append(CommonBatteryInfo(deviceController: self))
        componentControllers.append(AnafiFlightMeter(deviceController: self))
        componentControllers.append(CameraFeatureExposureValues(deviceController: self))
        componentControllers.append(AnafiFlightInfo(deviceController: self))
        componentControllers.append(AnafiTakeoffChecklist(deviceController: self))
        componentControllers.append(AnafiAnemometer(deviceController: self))
        // Peripherals
        componentControllers.append(AnafiMagnetometer(deviceController: self))
        componentControllers.append(HttpMediaStore(deviceController: self))
        componentControllers.append(AnafiSystemInfo(deviceController: self))
        componentControllers.append(HttpDtedStore(deviceController: self))
        componentControllers.append(LineOfSightController(deviceController: self))

        componentControllers.append(MissionUpdaterController(deviceController: self))
        if let firmwareStore = engine.utilities.getUtility(Utilities.firmwareStore),
           let firmwareDownloader = engine.utilities.getUtility(Utilities.firmwareDownloader) {
            componentControllers.append(
                DeviceUpdaterController(deviceController: self,
                                  config: UpdaterController.Config(deviceModel: deviceModel, uploaderType: .http),
                                  firmwareStore: firmwareStore, firmwareDownloader: firmwareDownloader))
        }
        componentControllers.append(AnafiCopterMotors(deviceController: self))
        if let crashReportStorage = engine.utilities.getUtility(Utilities.crashReportStorage) {
            componentControllers.append(
                HttpCrashmlDownloader(deviceController: self, crashReportStorage: crashReportStorage))
        }
        if let flightDataStorage = engine.utilities.getUtility(Utilities.flightDataStorage) {
            componentControllers.append(
                HttpFlightDataDownloader(deviceController: self, flightDataStorage: flightDataStorage))
        }
        if let flightLogConverterStorage = engine.utilities.getUtility(Utilities.flightLogConverterStorage) {
            componentControllers.append(
                HttpFlightLogDownloader(deviceController: self, flightLogConverterStorage: flightLogConverterStorage))
        } else if let flightLogStorage =  engine.utilities.getUtility(Utilities.flightLogStorage) {
            componentControllers.append(
                HttpFlightLogDownloader(deviceController: self, flightLogStorage: flightLogStorage))
        }
        if let flightCameraRecordStorage = engine.utilities.getUtility(Utilities.flightCameraRecordStorage) {
            componentControllers.append(
                HttpFlightCameraRecordDownloader(deviceController: self,
                                                 flightCameraRecordStorage: flightCameraRecordStorage))
        }
        componentControllers.append(AnafiWifiFeature(deviceController: self))
        componentControllers.append(RemovableUserStorageController(deviceController: self))
        componentControllers.append(InternalUserStorageController(deviceController: self))
        componentControllers.append(AnafiBeeper(deviceController: self))
        componentControllers.append(GimbalFeatureGimbal(deviceController: self))
        componentControllers.append(GimbalFeatureFrontStereoGimbal(deviceController: self))
        componentControllers.append(TargetTrackerController(deviceController: self))
        componentControllers.append(AnafiGeofence(deviceController: self))
        componentControllers.append(PreciseHomeController(deviceController: self))
        componentControllers.append(LedsController(deviceController: self))
        componentControllers.append(PhotoProgressIndicatorController(deviceController: self))
        componentControllers.append(AnafiPilotingControl(deviceController: self))
        componentControllers.append(OnboardTrackerController(deviceController: self))
        componentControllers.append(BatteryGaugeUpdaterController(deviceController: self))
        componentControllers.append(DriController(deviceController: self))
        componentControllers.append(AnafiStereoVisionSensor(deviceController: self))
        componentControllers.append(LogControlController(deviceController: self))
        componentControllers.append(CellularController(deviceController: self))
        componentControllers.append(ObstacleAvoidanceController(deviceController: self))
        if GroundSdkConfig.sharedInstance.enableDevToolbox {
            componentControllers.append(AnafiDevToolbox(deviceController: self))
        }
        componentControllers.append(MissionManagerController(deviceController: self))
        componentControllers.append(NetworkController(deviceController: self))
        componentControllers.append(FlightCameraRecorderController(deviceController: self))
        componentControllers.append(AnafiPrivacy(deviceController: self))
        componentControllers.append(ArsdkLatestLogDownloader(deviceController: self))
        componentControllers.append(HttpServerController(deviceController: self))
        componentControllers.append(Anafi2ConnectivityRouter(deviceController: self))
        componentControllers.append(AnafiNavigationController(deviceController: self))
        componentControllers.append(AnafiUnguardedFlight(deviceController: self))
        componentControllers.append(AnafiNightVision(deviceController: self))
        componentControllers.append(AnafiUsbPower(deviceController: self))
        componentControllers.append(ESimController(deviceController: self))

        switch model {
        case .anafi4k,
             .anafiThermal,
             .anafiUa,
             .anafiUsa:
            componentControllers.append(StreamServerController(
                deviceController: self,
                maxConcurrentStreams: 1,
                liveSourceMap: { src in src == .frontCamera ? .unspecified: src }
            ))
            componentControllers.append(CameraFeatureAntiflicker(deviceController: self))
            componentControllers.append(CameraFeatureCameraRouter(deviceController: self))
            componentControllers.append(AnafiThermalController(deviceController: self))
            componentControllers.append(AnafiCertificateUploader(deviceController: self))
        case .anafi3,
             .anafi3Gov,
             .anafi3Mil,
             .chuck3:
            componentControllers.append(Anafi3ThermalController(deviceController: self))
            componentControllers.append(ThermalController2(deviceController: self))
            componentControllers.append(Anafi3KillSwitch(deviceController: self))
            componentControllers.append(Anafi3Messenger(deviceController: self))
            componentControllers.append(Anafi3SleepMode(deviceController: self))
            componentControllers.append(ExternalAutopilotDebugController(deviceController: self))
            fallthrough
        case .anafi2: // also for above models
            componentControllers.append(StreamServerController(deviceController: self))
            componentControllers.append(Anafi2Antiflicker(deviceController: self))
            componentControllers.append(Camera2Router(deviceController: self))
            componentControllers.append(Anafi2CertificateUploader(deviceController: self))
            componentControllers.append(SecureElementController(deviceController: self))
            componentControllers.append(Anafi2StreamSharingOverlay(deviceController: self))
            componentControllers.append(CellularLogsController(deviceController: self))
            componentControllers.append(Anafi2CellularSession(deviceController: self))
            componentControllers.append(DebugShellController(deviceController: self))
            componentControllers.append(AnafiTerrainControl(deviceController: self))
        }

        sendDateAndTime = { [weak self] in
            let currentDate = Date()

            // send date/time
            let currentDateStr = ArsdkEngine.iso8601DateFormatter.string(from: currentDate)
            _ = self?.sendCommand(ArsdkFeatureCommonCommon.currentDateTimeEncoder(datetime: currentDateStr))

            if let eventLogger = self?.engine.utilities.getUtility(Utilities.eventLogger) {
                eventLogger.log("EVT:SEND_TIME;time='\(currentDateStr)'")
            }
        }
    }

    override func protocolDidConnect() {
        (ephemerisConfig?.uploader as? HttpEphemerisUploader)?.droneServer = deviceServer
        super.protocolDidConnect()
    }

    override func protocolDidDisconnect() {
        (ephemerisConfig?.uploader as? HttpEphemerisUploader)?.droneServer = nil
        super.protocolDidDisconnect()
    }

    override func protocolDidReceiveCommand(_ command: OpaquePointer) {
        super.protocolDidReceiveCommand(command)
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        }
    }
}

extension AnafiFamilyDroneController: ArsdkFeatureArdrone3PilotingstateCallback {
    func onFlyingStateChanged(state: ArsdkFeatureArdrone3PilotingstateFlyingstatechangedState) {
        self.isLanded = (state == .landed || state == .emergency)
    }
}
