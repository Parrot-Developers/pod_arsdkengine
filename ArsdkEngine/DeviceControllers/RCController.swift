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

/// Device controller for a RC (Remote Control).
class RCController: DeviceController {

    /// The remote antenna connected to the controlled RC.
    class RemoteAntenna: ArsdkRemoteantennaEventDecoderListener {

        /// Remote antenna's unique identifier.
        private(set) var uid: String?

        /// Remote antenna's device model.
        private(set) var model: DeviceModel?

        /// Remote antenna firmware version.
        private(set) var firmwareVersion: FirmwareVersion?

        /// Remote antenna device http server
        var deviceServer: DeviceServer?

        /// Device controller
        private var deviceController: DeviceController

        /// The tcp proxy if it exists.
        /// Always nil when not connected.
        fileprivate private(set) var arsdkTcpProxy: ArsdkTcpProxy?

        /// Decoder for remote antenna events.
        var arsdkDecoder: ArsdkRemoteantennaEventDecoder!

        /// Whether TCP proxy is created or not.
        private var isTcpProxyCreated: Bool = false {
            didSet {

                guard isTcpProxyCreated != oldValue else { return }

                if isTcpProxyCreated {
                    if isDeviceInfoReceived {
                        deviceController.componentControllers.forEach { controller in
                            controller.remoteAntennaDidConnect()
                        }
                    }
                } else {
                    deviceController.componentControllers.forEach { controller in
                        controller.remoteAntennaDidDisconnect()
                    }
                }
            }
        }

        /// Whether device info event has been received or not.
        private var isDeviceInfoReceived: Bool = false {
            didSet {

                guard isDeviceInfoReceived != oldValue else { return }

                if isDeviceInfoReceived && isTcpProxyCreated {
                    deviceController.componentControllers.forEach { controller in
                        controller.remoteAntennaDidConnect()
                    }
                }
            }
        }

        /// Whether the remote antenna is connected and active or not.
        fileprivate(set) var isActive: Bool = false {
            didSet {

                guard isActive != oldValue else { return }

                if isActive {
                    createTcpProxy()
                } else {
                    uid = nil
                    model = nil
                    firmwareVersion = nil
                    isDeviceInfoReceived = false
                    closeTcpProxy()
                }
            }
        }

        /// Constructor
        ///
        /// - Parameter deviceController: the device controller
        init(deviceController: DeviceController) {
            self.deviceController = deviceController
            self.arsdkDecoder = ArsdkRemoteantennaEventDecoder(listener: self)
        }

        /// Create tcp proxy
        private func createTcpProxy() {
            deviceController.backend?.createTcpProxy(
                url: "remote_antenna", port: 80, completion: { [weak self] proxy, address, port in
                    guard let self = self else { return }

                    self.arsdkTcpProxy = proxy

                    if let address = address, port != 0 {
                        deviceServer = DeviceServer(address: address, port: port)
                    }
                    isTcpProxyCreated = true
                })
        }

        /// Close tcp proxy
        private func closeTcpProxy() {
            isTcpProxyCreated = false
            deviceServer = nil
            arsdkTcpProxy = nil
        }

        func onState(_ state: Arsdk_Remoteantenna_Event.State) {
            if state.hasAntennaStatus {
                self.isActive = state.antennaStatus.value == .active
            }
            if self.isActive {
                if state.hasDeviceInfo {
                    if !state.deviceInfo.serial.isEmpty {
                        uid = state.deviceInfo.serial
                        model = DeviceModel.from(internalId: Int(state.deviceInfo.model))
                        firmwareVersion = FirmwareVersion.parse(versionStr: state.deviceInfo.firmwareVersion)
                        isDeviceInfoReceived = true
                    }
                }
            }
        }

        func onDiscoveredCloudAntennas(_ discoveredCloudAntennas: Arsdk_Remoteantenna_Event.DiscoveredCloudAntennas) {
            // nothing to do
        }

        func onHeading(_ heading: Arsdk_Remoteantenna_Event.Heading) {
            // nothing to do
        }
    }

    /// Get the drone managed by this controller
    var remoteControl: RemoteControlCore {
        return device as! RemoteControlCore
    }

    /// Remote control black box subscription
    private var rcBlackBoxSubscription: ArsdkRequest?

    /// Monitor of the userAccount changes
    private var userAccountMonitor: MonitorCore!

    /// Monitor the userLocation (with systemPositionUtility)
    private var userLocationMonitor: MonitorCore?

    /// Decoder for mobile device events.
    private var arsdkMobileDeviceDecoder: ArsdkMobiledeviceEventDecoder!

    /// The remote antenna connected to the controlled RC.
    public private(set) var remoteAntenna: RemoteAntenna!

    /// Constructor
    ///
    /// - Parameters:
    ///    - engine: arsdk engine instance
    ///    - deviceUid: device uid
    ///    - model: rc model
    ///    - name: rc name
    init(engine: ArsdkEngine, deviceUid: String, model: RemoteControl.Model, name: String) {
        super.init(engine: engine, deviceUid: deviceUid, deviceModel: .rc(model)) { delegate in
            return RemoteControlCore(uid: deviceUid, model: model, name: name, delegate: delegate)
        }
        self.getAllSettingsEncoder = ArsdkFeatureSkyctrlSettings.allSettingsEncoder()
        self.getAllStatesEncoder = ArsdkFeatureSkyctrlCommon.allStatesEncoder()

        if let eventLogger = engine.utilities.getUtility(Utilities.eventLogger) {
            deviceEventLogger = RCEventLogger(eventLog: eventLogger, engine: self.engine, device: self.device)
        }
        arsdkMobileDeviceDecoder = ArsdkMobiledeviceEventDecoder(listener: self)
        remoteAntenna = RemoteAntenna(deviceController: self)
    }

    /// Device controller did start
    override func controllerDidStart() {
        super.controllerDidStart()
        // Can force unwrap remote control store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.remoteControlStore)!.add(remoteControl)
    }

    /// Device controller did stop
    override func controllerDidStop() {
        super.controllerDidStop()
        // Can force unwrap remote control store utility because we know it is always available after the engine's start
        engine.utilities.getUtility(Utilities.remoteControlStore)!.remove(remoteControl)

        userAccountMonitor?.stop()
        userAccountMonitor = nil
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: UIScene.didEnterBackgroundNotification, object: nil)
    }

    override func protocolWillConnect() {
        super.protocolWillConnect()
        _ = sendGetCapabilitiesCommand()

        if let blackBoxRecorder = engine.blackBoxRecorder {
            let blackBoxRcSession = blackBoxRecorder.openRemoteControlSession(remoteControl: remoteControl)
            blackBoxSession = blackBoxRcSession

            // can force unwrap backend since we are connecting
            rcBlackBoxSubscription = backend!.subscribeToRcBlackBox(buttonAction: { action in
                blackBoxRcSession.buttonHasBeenTriggered(action: Int(action))
            }, pilotingInfo: { pitch, roll, yaw, gaz, source in
                blackBoxRcSession.rcPilotingCommandDidChange(
                    roll: Int(roll), pitch: Int(pitch), yaw: Int(yaw), gaz: Int(gaz), source: Int(source))
            })
        }
    }

    override func protocolDidConnect() {
        super.protocolDidConnect()
        let userAccountUtility = engine.utilities.getUtility(Utilities.userAccount)!
        // monitor userAccount changes
        userAccountMonitor = userAccountUtility.startMonitoring(accountDidChange: { (newUserAccountInfo) in
            if let token = newUserAccountInfo?.token {
                self.sendToken(token)
            }
            if let droneList = newUserAccountInfo?.droneList {
                self.sendDroneList(droneList)
            }
            if let cloudAntennaList = newUserAccountInfo?.cloudAntennaList {
                self.sendCloudAntennaList(cloudAntennaList)
            }
        })
    }

    override func protocolDidDisconnect() {
        super.protocolDidDisconnect()
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        rcBlackBoxSubscription?.cancel()
        rcBlackBoxSubscription = nil
        remoteAntenna?.isActive = false
        // stop monitoring subscription
        userLocationMonitor?.stop()
        userLocationMonitor = nil
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func protocolDidReceiveCommand(_ command: OpaquePointer) {
        // settings/state
        switch ArsdkCommand.getFeatureId(command) {
        case kArsdkFeatureSkyctrlSettingsstateUid:
            ArsdkFeatureSkyctrlSettingsstate.decode(command, callback: self)
        case kArsdkFeatureSkyctrlCommonstateUid:
            ArsdkFeatureSkyctrlCommonstate.decode(command, callback: self)
        case kArsdkFeatureGenericUid:
            remoteAntenna.arsdkDecoder.decode(command)
            arsdkMobileDeviceDecoder.decode(command)
        default:
            break
        }
        super.protocolDidReceiveCommand(command)
    }

    /// Send user account token
    ///
    /// - Parameter token: user account token
    private func sendToken(_ token: String) {
        var tokenCommand = Arsdk_Security_Command.RegisterApcToken()
        tokenCommand.token = token
        sendSecurityTokenCommand(.registerApcToken(tokenCommand))
    }

    /// Send drone list
    ///
    /// - Parameter droneList: drone list
    private func sendDroneList(_ droneList: String) {
        var droneListCommand = Arsdk_Security_Command.RegisterApcDroneList()
        droneListCommand.list = droneList
        sendSecurityTokenCommand(.registerApcDroneList(droneListCommand))
    }

    /// Send cloud antenna list
    ///
    /// - Parameter cloudAntennaList: cloud antenna list
    private func sendCloudAntennaList(_ cloudAntennaList: String) {
        var cloudAntennaListCommand = Arsdk_Security_Command.RegisterApcCloudAntennaList()
        cloudAntennaListCommand.list = cloudAntennaList
        sendSecurityTokenCommand(.registerApcCloudAntennaList(cloudAntennaListCommand))
    }

    /// Sends to the drone a security command.
    ///
    /// - Parameter command: command to send
    private func sendSecurityTokenCommand(_ command: Arsdk_Security_Command.OneOf_ID) {
        if let encoder = ArsdkSecurityCommandEncoder.encoder(command) {
            _ = sendCommand(encoder)
        }
    }

    /// Start system positon
    private func startSystemPosition() {
        let systemPositionUtility = engine.utilities.getUtility(Utilities.systemPosition)
        if let systemPositionUtility {
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
    }

    /// Processes system geographic location changes and sends them to the remote.
    private func locationDidChange(_ newLocation: CLLocation) {
        // controller speed validity.
        let speedIsValid = { () -> Bool in
            guard newLocation.speedAccuracy >= 0 else { return false }
            if newLocation.speed == 0.0 {
                return true
            } else {
                return newLocation.courseAccuracy >= 0 && newLocation.courseAccuracy < 180.0
            }
        }
        var location = Arsdk_Mobiledevice_Command.Location()
        location.timestamp = Google_Protobuf_UInt64Value(UInt64(newLocation.timestamp.timeIntervalSince1970 * 1000))
        location.source = .sourceMain
        location.latitude = Google_Protobuf_DoubleValue(newLocation.coordinate.latitude)
        location.longitude = Google_Protobuf_DoubleValue(newLocation.coordinate.longitude)
        location.amslAltitude = Google_Protobuf_FloatValue(Float(newLocation.altitude))
        let horizontalAccuracy =
            Google_Protobuf_FloatValue(Float(newLocation.horizontalAccuracy / 2.0.squareRoot()))
        location.latitudeAccuracy = horizontalAccuracy
        location.longitudeAccuracy = horizontalAccuracy
        location.amslAltitudeAccuracy =
            Google_Protobuf_FloatValue(Float(newLocation.verticalAccuracy))
        if speedIsValid() {
            let courseRad = newLocation.course.toRadians()
            location.northVelocity = Google_Protobuf_FloatValue(Float(cos(courseRad) * newLocation.speed))
            location.eastVelocity = Google_Protobuf_FloatValue(Float(sin(courseRad) * newLocation.speed))
            location.velocityAccuracy = Google_Protobuf_FloatValue(Float(newLocation.speedAccuracy))
            location.velocityAccuracy = Google_Protobuf_FloatValue(Float(newLocation.speedAccuracy))
        }
        _ = sendMobileDeviceCommand(.location(location))
    }

    /// Sends get capabilities command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetCapabilitiesCommand() -> Bool {
        return sendMobileDeviceCommand(.getCapabilities(Google_Protobuf_Empty()))
    }

    /// Sends to the drone a Mobile device command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendMobileDeviceCommand(_ command: Arsdk_Mobiledevice_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkMobiledeviceCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Skyctrl settings events dispatcher, used to receive onAllSettingsChanged
extension RCController: ArsdkFeatureSkyctrlSettingsstateCallback {
    func onAllSettingsChanged() {
        if connectionSession.state == .gettingAllSettings {
            transitToNextConnectionState()
        }
    }

    func onProductVersionChanged(software: String, hardware: String) {
        if let firmwareVersion = FirmwareVersion.parse(versionStr: software) {
            device.firmwareVersionHolder.update(version: firmwareVersion)
            deviceStore.write(key: PersistentStore.deviceFirmwareVersion, value: software).commit()
        }
    }
}

/// Skyctrl state events dispatcher, used to receive onAllStatesChanged
extension RCController: ArsdkFeatureSkyctrlCommonstateCallback {
    func onAllStatesChanged() {
        if connectionSession.state == .gettingAllStates {
            transitToNextConnectionState()
        }
    }

    func onImminentShutdownChanged(duration: Int) {
        device.stateHolder.state.update(willShutDownIn: duration).notifyUpdated()
    }
}

/// Skyctrl Common event state dispatcher, used to receive onShutdown
extension RCController: ArsdkFeatureSkyctrlCommoneventstateCallback {
    func onShutdown(reason: ArsdkFeatureSkyctrlCommoneventstateShutdownReason) {
        if reason == ArsdkFeatureSkyctrlCommoneventstateShutdownReason.poweroffButton {
            autoReconnect = false
            _ = doDisconnect(cause: .userRequest)
        }
    }
}

/// Mobile device events, used to received capabilities
extension RCController: ArsdkMobiledeviceEventDecoderListener {
    func onCapabilities(_ capabilities: Arsdk_Mobiledevice_Event.Capabilities) {
        if capabilities.supportedFeatures.contains(.location) {
            startSystemPosition()
        }
    }
}
