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
import CoreLocation

/// Gps command supported enum
public enum GpsCommandSupported: Int, CustomStringConvertible {
    /// gps command supported
    case gps
    /// gps_v2 command supported
    case gps_v2

    /// Debug description.
    public var description: String {
        switch self {
        case .gps: return "gps"
        case .gps_v2: return "gps_v2"
        }
    }
}

/// Device controller for a drone.
class DroneController: DeviceController {

    /// Piloting activation controller
    var pilotingItfActivationController: PilotingItfActivationController!

    /// Whether or not the piloting command is running
    var pcmdRunning = false

    /// Get the drone managed by this controller
    var drone: DroneCore {
        return device as! DroneCore
    }

    /// Ephemeris config
    var ephemerisConfig: EphemerisConfig?

    /// Ephemeris utility
    private var ephemerisUtility: EphemerisUtilityCore?

    /// Whether the drone is landed or not
    ///
    /// Should be set by subclasses
    var isLanded = false {
        didSet {
            guard isLanded != oldValue else {
                return
            }
            dataSyncAllowanceMightHaveChanged()
        }
    }

    /// Utility for device's location services.
    private var systemPositionUtility: SystemPositionCore?
    /// Monitor the userLocation (with systemPositionUtility)
    private var userLocationMonitor: MonitorCore?

    /// Utility for device's barometer services.
    private var systemBarometerUtility: SystemBarometerCore?
    /// Monitor the barometer (with systemBarometerUtility)
    private var userBarometerMonitor: MonitorCore?

    override var dataSyncAllowed: Bool {
        return super.dataSyncAllowed && isLanded
    }

    /// Gps command is supported (capabilities were received)
    private var gpsCommandSupported = Set<GpsCommandSupported>()

    /// Bitfield of available data
    private var availableData: UInt?

    /// Constructor
    ///
    /// - Parameters:
    ///     - engine: arsdk engine instance
    ///     - deviceUid: device uid
    ///     - model: drone model
    ///     - name: drone name
    ///     - pcmdEncoder: Piloting command encoder. The `pcmdEncoder.pilotingCommandPeriod` will fix the period of
    ///       the NoAckCommandLoop
    ///     - ephemerisConfig: ephemeris config or nil if not supported by drone
    ///         default value is nil
    ///     - defaultPilotingItfFactory: Closure that will create the default piloting interface.
    init(engine: ArsdkEngine, deviceUid: String, model: Drone.Model, name: String,
         pcmdEncoder: PilotingCommandEncoder,
         ephemerisConfig: EphemerisConfig? = nil,
         defaultPilotingItfFactory: ((PilotingItfActivationController) -> ActivablePilotingItfController)) {

        self.ephemerisConfig = ephemerisConfig
        super.init(engine: engine, deviceUid: deviceUid,
                   deviceModel: .drone(model),
                   noAckLoopPeriod: pcmdEncoder.pilotingCommandPeriod) {  delegate in
                    return DroneCore(uid: deviceUid, model: model, name: name, delegate: delegate)
        }

        pilotingItfActivationController = PilotingItfActivationController(
            droneController: self, pilotingCommandEncoder: pcmdEncoder,
            defaultPilotingItfFactory: defaultPilotingItfFactory)

        getAllSettingsEncoder = ArsdkFeatureCommonSettings.allSettingsEncoder()
        getAllStatesEncoder = ArsdkFeatureCommonCommon.allStatesEncoder()

        ephemerisUtility = engine.utilities.getUtility(Utilities.ephemeris)
        if let eventLogger = engine.utilities.getUtility(Utilities.eventLogger) {
            deviceEventLogger = DroneEventLogger(eventLog: eventLogger, engine: self.engine, device: self.device)
        }
    }

    /// Called back when the current piloting command sent to the drone changes.
    ///
    /// - Parameter pilotingCommand: up-to-date piloting command
    func pilotingCommandDidChange(_ pilotingCommand: PilotingCommand) {
        if let blackBoxSession = blackBoxSession as? BlackBoxDroneSession {
            blackBoxSession.pilotingCommandDidChange(pilotingCommand)
        }
    }

    /// Creates a video live stream source.
    ///
    /// - Parameter cameraType: stream camera type
    /// - Returns: a new instance of a live stream source
    func createVideoSourceLive(cameraType: ArsdkSourceLiveCameraType) -> ArsdkSourceLive? {
        if let backend = backend {
            return backend.createVideoSourceLive(cameraType: cameraType)
        } else {
            ULog.w(.ctrlTag, "createVideoSourceLive called without backend")
        }
        return nil
    }

    /// Creates a media stream source.
    ///
    /// - Parameters:
    ///    - url: stream url
    ///    - trackName: stream track name
    /// - Returns: a new instance of a media stream source
    func createVideoSourceMedia(url: String, trackName: String?) -> ArsdkSourceMedia? {
        if let backend = backend {
            return backend.createVideoSourceMedia(url: url, trackName: trackName)
        } else {
            ULog.w(.ctrlTag, "createVideoSourceMedia called without backend")
        }
        return nil
    }

    /// Create a video stream instance.
    ///
    /// - Parameter listener: the listener that should be called for stream events
    /// - Returns: a new instance of a stream
    func createVideoStream(listener: ArsdkStreamListener) -> ArsdkStream? {
        if let backend = backend {
            return backend.createVideoStream(listener: listener)
        } else {
            ULog.w(.ctrlTag, "createVideoStream called without backend")
        }
        return nil
    }

    /// Device controller did start
    override func controllerDidStart() {
        super.controllerDidStart()
        // publish drone
        // Can force unwrap drone store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.droneStore)!.add(drone)
    }

    /// Device controller did stop
    override func controllerDidStop() {
        // unpublish drone
        // Can force unwrap drone store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.droneStore)!.remove(drone)
    }

    override func protocolWillConnect() {
        super.protocolWillConnect()

        if let blackBoxRecorder = engine.blackBoxRecorder {
            var providerUid: String?
            if  activeProvider?.connector.connectorType == .remoteControl {
                providerUid = activeProvider?.connector.uid
            }
            blackBoxSession = blackBoxRecorder.openDroneSession(drone: drone, providerUid: providerUid)
        }
    }

    override func protocolDidConnect() {
        pilotingItfActivationController.didConnect()
        super.protocolDidConnect()
        /// Utility for device's location services.
        systemPositionUtility = engine.utilities.getUtility(Utilities.systemPosition)
        if let systemPositionUtility = systemPositionUtility {
            userLocationMonitor = systemPositionUtility.startLocationMonitoring(
                passive: false, userLocationDidChange: { [unowned self] newLocation in
                    if let newLocation = newLocation {
                        // Check that the location is not too old (15 sec max)
                        if abs(newLocation.timestamp.timeIntervalSinceNow) <= 15 {
                            // this position is valid and can be sent to the drone
                            self.locationDidChange(newLocation)
                        } else {
                             ULog.d(.ctrlTag,
                                    "reject old timestamp Location \(abs(newLocation.timestamp.timeIntervalSinceNow))")
                        }
                    }
                }, stoppedDidChange: {_ in }, authorizedDidChange: {_ in })
        }

        systemBarometerUtility = engine.utilities.getUtility(Utilities.systemBarometer)
        if let systemBarometerUtility = systemBarometerUtility {
            // monitoring the barometer
            userBarometerMonitor = systemBarometerUtility.startMonitoring(
                measureDidChange: { [unowned self] barometerMeasure in
                    if let barometerMeasure = barometerMeasure {
                        self.sendCommand(ArsdkFeatureControllerInfo.barometerEncoder(
                            pressure: Float(barometerMeasure.pressure),
                            timestamp: barometerMeasure.timestamp.timeIntervalSince1970 * 1000))
                    }
            })
        }
        uploadEphemerisIfAllowed()
    }

    override func protocolDidDisconnect() {
        // stop monitoring location
        userLocationMonitor?.stop()
        userLocationMonitor = nil

        // stop monitoring barometer
        userBarometerMonitor?.stop()
        userBarometerMonitor = nil

        gpsCommandSupported.removeAll()
        availableData = nil
        pilotingItfActivationController.didDisconnect()
        super.protocolDidDisconnect()

        if let eventLogger = engine.utilities.getUtility(Utilities.eventLogger) {
            eventLogger.newSession()
        }
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func protocolDidReceiveCommand(_ command: OpaquePointer) {
        deviceEventLogger?.onCommandReceived(command: command)
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonSettingsstateUid {
            ArsdkFeatureCommonSettingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonCommonstateUid {
            ArsdkFeatureCommonCommonstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonNetworkeventUid {
            ArsdkFeatureCommonNetworkevent.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureSkyctrlCommoneventstateUid {
            ArsdkFeatureSkyctrlCommoneventstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureControllerInfoUid {
            ArsdkFeatureControllerInfo.decode(command, callback: self)
        }

        super.protocolDidReceiveCommand(command)
    }

    override func firmwareDidUpload() {
        sendCommand(ArsdkFeatureCommonCommon.rebootEncoder())
    }

    private func uploadEphemerisIfAllowed() {
        if let ephemerisConfig = ephemerisConfig,
            let ephemerisUrl = ephemerisUtility?.getLatestEphemeris(forType: ephemerisConfig.fileType),
            dataSyncAllowed {
            ephemerisConfig.uploader.upload(ephemeris: ephemerisUrl)
        }
    }

    /// Processes system geographic location changes and sends them to the drone.
    private func locationDidChange(_ newLocation: CLLocation) {
        // converts speed and cource in north / east values
        var northSpeed = 0.0
        var eastSpeed = 0.0
        var speedAccuracy = 0.0
        var availableDataBitfield: UInt = (Bitfield<ArsdkFeatureControllerInfoAvailableData>.of(.amslAltitude,
            .altitudeAccuracy))

        // controller speed validity.
        let speedIsValid = { () -> Bool in
            guard newLocation.speedAccuracy >= 0 else { return false }
            if newLocation.speed == 0.0 {
                return true
            } else if #available(iOS 13.4, *) {
                return newLocation.courseAccuracy >= 0 && newLocation.courseAccuracy < 180.0
            } else {
                return newLocation.course >= 0
            }
        }

        if speedIsValid() {
            let courseRad = newLocation.course.toRadians()
            northSpeed = cos(courseRad) * newLocation.speed
            eastSpeed = sin(courseRad) * newLocation.speed
            speedAccuracy = newLocation.speedAccuracy
            availableDataBitfield = availableDataBitfield
                | Bitfield<ArsdkFeatureControllerInfoAvailableData>.of(.northVelocity, .eastVelocity, .velocityAccuracy)
        }

        // log controller location debug
        if #available(iOS 13.4, *) {
            ULog.d(.ctrlTag, "newLocation \(newLocation) |\n" +
                    " .speed: \(newLocation.speed) .speedAccuracy: \(newLocation.speedAccuracy)" +
                    " .course: \(newLocation.course) .courseAccuracy: \(newLocation.courseAccuracy) |\n" +
                    " northSpeed: \(northSpeed) eastSpeed: \(eastSpeed) speedAccuracy: \(speedAccuracy)" +
                    " availableDataBitfield: 0x\(String(format: "%02X", availableDataBitfield))")

            if newLocation.speed > 2 && newLocation.courseAccuracy > 45 {
                GroundSdkCore.logEvent(message: "EVT:LOCATION;event='warning';" +
                    "speed='\(newLocation.speed)';" +
                    "course_accuracy='\(newLocation.courseAccuracy)'")
            }
        } else {
            ULog.d(.ctrlTag, "newLocation \(newLocation) |\n" +
                    " .speed: \(newLocation.speed) .speedAccuracy: \(newLocation.speedAccuracy)" +
                    " .course: \(newLocation.course) .courseAccuracy: --- |\n" +
                    " northSpeed: \(northSpeed) eastSpeed: \(eastSpeed) speedAccuracy: \(speedAccuracy)" +
                    " availableDataBitfield: 0x\(String(format: "%02X", availableDataBitfield))")
        }

        if gpsCommandSupported.contains(.gps_v2) {
            // Send available data to drone.
            if availableData != availableDataBitfield {
                availableData = availableDataBitfield
                sendCommand(ArsdkFeatureControllerInfo.gpsV2AvailableDataEncoder(source: .main,
                    availableDataBitField: availableData!))
            }

            // send command :
            //        - Parameter source: source of data. In this case it is .main
            //        - Parameter latitude: Latitude of the controller (in deg)
            //        - Parameter longitude: Longitude of the controller (in deg)
            //        - Parameter amslAltitude: Altitude of the controller (in meters, according to sea level)
            //        - Parameter wgs84Altitude: Altitude of the controller (in meters, according to sea level)
            //        - Parameter latitudeAccuracy: Latitude accuracy / sqrt(2) (in meter)
            //        - Parameter longitudeAccuracy: Longitude accuracy / sqrt(2) (in meter)
            //        - Parameter altitudeAccuracy: Vertical accuracy (in meter)
            //        - Parameter northVelocity: North speed (in meter per second)
            //        - Parameter eastVelocity: East speed (in meter per second)
            //        - Parameter upVelocity: Vertical speed (in meter per second) (down is positive)
            //          -> force 0 for downSpeed
            //        - Parameter velocityAccuracy: Velocity accuracy
            //        - Parameter timestamp: Timestamp of the gps info
            sendCommand(ArsdkFeatureControllerInfo.gpsV2Encoder(
                source: .main,
                latitude: newLocation.coordinate.latitude, longitude: newLocation.coordinate.longitude,
                amslAltitude: Float(newLocation.altitude), wgs84Altitude: 0,
                latitudeAccuracy: Float(newLocation.horizontalAccuracy / 2.0.squareRoot()),
                longitudeAccuracy: Float(newLocation.horizontalAccuracy / 2.0.squareRoot()),
                altitudeAccuracy: Float(newLocation.verticalAccuracy), northVelocity: Float(northSpeed),
                eastVelocity: Float(eastSpeed), upVelocity: 0, velocityAccuracy: Float(speedAccuracy),
                numberOfSatellites: 0,
                timestamp: UInt64(newLocation.timestamp.timeIntervalSince1970 * 1000)))
        } else {
            // send command :
            //        - Parameter latitude: Latitude of the controller (in deg)
            //        - Parameter longitude: Longitude of the controller (in deg)
            //        - Parameter altitude: Altitude of the controller (in meters, according to sea level)
            //        - Parameter horizontalAccuracy: Horizontal accuracy (in meter)
            //        - Parameter verticalAccuracy: Vertical accuracy (in meter)
            //        - Parameter northSpeed: North speed (in meter per second)
            //        - Parameter eastSpeed: East speed (in meter per second)
            //        - Parameter downSpeed: Vertical speed (in meter per second) (down is positive)
            //          -> force 0 for downSpeed
            //        - Parameter timestamp: Timestamp of the gps info
            sendCommand(ArsdkFeatureControllerInfo.gpsEncoder(
                latitude: newLocation.coordinate.latitude, longitude: newLocation.coordinate.longitude,
                altitude: Float(newLocation.altitude), horizontalAccuracy: Float(newLocation.horizontalAccuracy),
                verticalAccuracy: Float(newLocation.verticalAccuracy), northSpeed: Float(northSpeed),
                eastSpeed: Float(eastSpeed), downSpeed: 0,
                timestamp: newLocation.timestamp.timeIntervalSince1970 * 1000))
        }
    }
}

/// Common settings events dispatcher, used to receive onAllSettingsChanged
extension DroneController: ArsdkFeatureCommonSettingsstateCallback {
    func onAllSettingsChanged() {
        if connectionSession.state == .gettingAllSettings {
            transitToNextConnectionState()
        }
    }

    func onProductNameChanged(name: String!) {
        device.nameHolder.update(name: name)
        deviceStore.write(key: PersistentStore.deviceName, value: name).commit()
    }

    func onProductVersionChanged(software: String!, hardware: String!) {
        if let firmwareVersion = FirmwareVersion.parse(versionStr: software) {
            device.firmwareVersionHolder.update(version: firmwareVersion)
            deviceStore.write(key: PersistentStore.deviceFirmwareVersion, value: software).commit()
        }
    }

    func onBoardIdChanged(id: String!) {
        device.boardIdHolder.update(boardId: id)
        deviceStore.write(key: PersistentStore.deviceBoardId, value: id).commit()
    }
}

/// Common state events dispatcher, used to receive onAllStatesChanged
extension DroneController: ArsdkFeatureCommonCommonstateCallback {
    func onAllStatesChanged() {
        if connectionSession.state == .gettingAllStates {
            transitToNextConnectionState()
        }
    }

    func onBootId(bootid: String!) {
        if let eventLogger = engine.utilities.getUtility(Utilities.eventLogger) {
            eventLogger.update(bootId: bootid)
        }
    }
}

/// Network event dispatcher, used to receive onDisconnection
extension DroneController: ArsdkFeatureCommonNetworkeventCallback {
    func onDisconnection(cause: ArsdkFeatureCommonNetworkeventDisconnectionCause) {
        if cause == ArsdkFeatureCommonNetworkeventDisconnectionCause.offButton {
            autoReconnect = false
            _ = doDisconnect(cause: .userRequest)
        }
    }
}

/// Skyctrl Common event state dispatcher, used to receive onShutdown
extension DroneController: ArsdkFeatureSkyctrlCommoneventstateCallback {
    func onShutdown(reason: ArsdkFeatureSkyctrlCommoneventstateShutdownReason) {
        if reason == ArsdkFeatureSkyctrlCommoneventstateShutdownReason.poweroffButton {
            autoReconnect = false
            _ = doDisconnect(cause: .userRequest)
        }
    }
}

extension DroneController: ArsdkFeatureControllerInfoCallback {

    func onCapabilities(supportedCommandBitField: UInt) {
        gpsCommandSupported = GpsCommandSupported.createSetFrom(bitField: supportedCommandBitField)
    }
}

/// Extension that add conversion from/to arsdk enum
extension GpsCommandSupported: ArsdkMappableEnum {

    /// Create set of gps supported commands from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all gps command supported in bitField
    static func createSetFrom(bitField: UInt) -> Set<GpsCommandSupported> {
        var result = Set<GpsCommandSupported>()
        ArsdkFeatureControllerInfoSupportedCommandBitField.forAllSet(in: bitField) { arsdkValue in
            if let value = GpsCommandSupported(fromArsdk: arsdkValue) {
                result.insert(value)
            }
        }
        return result
    }

    static let arsdkMapper = Mapper<GpsCommandSupported, ArsdkFeatureControllerInfoSupportedCommand>([
        .gps: .gps,
        .gps_v2: .gpsV2])
}
