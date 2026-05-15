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

/// Base class for all Manual Copter piloting interface component controller
class ManualCopterPilotingItfController: ManualPilotingItfController, ManualCopterPilotingItfBackend,
                                         ManualPlanePilotingItfBackend {

    /// Key for manual copter piloting itf storage
    private static let settingKey = "ManualCopter"

    /// The piloting interface from which this object is the delegate
    var manualCopterPilotingItf: ManualCopterPilotingItfCore!

    /// The piloting interface from which this object is the delegate
    var manualPlanePilotingItf: ManualPlanePilotingItfCore!

    /// Decoder for piloting events.
    public var arsdkPilotingDecoder: ArsdkPilotingEventDecoder!

    /// Decoder for loiter events.
    public var arsdkLoiterDecoder: ArsdkLoiterEventDecoder!

    /// Store device specific values, like settings ranges and supported flags
    public let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    public var presetStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// Whether the drone is supporting hand launch
    public var isHandLaunchSupported: Bool = true

    /// Whether the drone is supporting preferred ATTI mode
    public var isPreferredAttiModeSupported = false

    /// All setting backends of this peripheral
    private var settings = [OfflineSetting]()

    /// Assistance mode setting backend
    internal var assistanceModeSetting: OfflineEnumSetting<AssistanceMode>!

    /// Loiter shape setting backend
    internal var loiterShapeSetting: OfflineEnumSetting<LoiterShape>!

    /// Loiter direction setting backend
    internal var loiterDirectionSetting: OfflineEnumSetting<LoiterDirection>!

    /// Loiter radius setting backend
    internal var loiterRadiusSetting: OfflineDoubleSetting!

    /// The vehicle mode
    internal var vehicleMode: VehicleMode = .copter {
        didSet {
            if vehicleMode != oldValue, vehicleType == .vtol {
                updatePilotingItf()
            }
        }
    }

    /// The vehicle type
    internal var vehicleType: VehicleType = .multicopter {
        didSet {
            manualCopterPilotingItf.update(vehicleType: vehicleType)
            manualPlanePilotingItf.update(vehicleType: vehicleType)
            if vehicleType == .vtol || vehicleType == .plane {
                _ = sendGetLoiterStateCommand()
            }
            if vehicleType != oldValue {
                updatePilotingItf()
            }
        }
    }

    /// Update the piloting interface depending on the vehicle type and the vehicle mode
    private func updatePilotingItf() {
        switch vehicleType {
        case .vtol:
            if vehicleMode == .plane {
                manualPlanePilotingItf.update(activeState: pilotingItf.state)
                manualCopterPilotingItf.update(activeState: connected ? .idle : .unavailable)
                pilotingItf = manualPlanePilotingItf
            } else {
                manualCopterPilotingItf.update(activeState: pilotingItf.state)
                manualPlanePilotingItf.update(activeState: connected ? .idle : .unavailable)
                pilotingItf = manualCopterPilotingItf
            }
            if connected {
                manualCopterPilotingItf.publish()
                manualPlanePilotingItf.publish()
            }
        case .helicopter, .multicopter:
            manualCopterPilotingItf.update(activeState: pilotingItf.state)
            manualPlanePilotingItf.unpublish()
            pilotingItf = manualCopterPilotingItf
            if connected {
                pilotingItf.publish()
            }
        case .plane:
            manualPlanePilotingItf.update(activeState: pilotingItf.state)
            manualCopterPilotingItf.unpublish()
            pilotingItf = manualPlanePilotingItf
            if connected {
                pilotingItf.publish()
            }
        }
    }

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case maxPitchRollKey = "maxPitchRoll"
        case maxHorizontalSpeedKey = "maxHorizontalSpeed"
        case speedModeKey = "speedMode"
        case maxPitchRollVelocityKey = "maxPitchRollVelocity"
        case maxVerticalSpeedKey = "maxVerticalSpeed"
        case maxYawRotationSpeedKey = "maxYawRotationSpeed"
        case takeoffHoveringAltitudeKey = "takeoffHoveringAltitude"
        case bankedTurnModeKey = "bankedTurnMode"
        case motionDetectionModeKey = "motionDetection"
        case vehicleTypeKey = "vehicleType"
        case assistanceModeKey = "assistanceMode"
        case loiterShapeKey = "loiterShape"
        case loiterDirectionKey = "loiterDirection"
        case loiterRadiusKey = "loiterRadius"
    }

    enum Setting: Hashable {
        case maxPitchRoll(Double, Double, Double)
        case maxHorizontalSpeed(Double, Double, Double)
        case speedMode(SpeedMode)
        case maxPitchRollVelocity(Double, Double, Double)
        case maxVerticalSpeed(Double, Double, Double)
        case maxYawRotationSpeed(Double, Double, Double)
        case takeoffHoveringAltitude(Double, Double?, Double)
        case bankedTurnMode(Bool)
        case motionDetectionMode(Bool)
        case vehicleType(VehicleType?)
        case assistanceMode(AssistanceMode)
        case loiterShape(LoiterShape)
        case loiterDirection(LoiterDirection)
        case loiterRadius(Double, Double, Double)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .maxPitchRoll: return .maxPitchRollKey
            case .maxHorizontalSpeed: return .maxHorizontalSpeedKey
            case .speedMode: return .speedModeKey
            case .maxPitchRollVelocity: return .maxPitchRollVelocityKey
            case .maxVerticalSpeed: return .maxVerticalSpeedKey
            case .maxYawRotationSpeed: return .maxYawRotationSpeedKey
            case .takeoffHoveringAltitude: return .takeoffHoveringAltitudeKey
            case .bankedTurnMode: return .bankedTurnModeKey
            case .motionDetectionMode: return .motionDetectionModeKey
            case .vehicleType: return .vehicleTypeKey
            case .assistanceMode: return .assistanceModeKey
            case .loiterShape: return .loiterShapeKey
            case .loiterDirection: return .loiterDirectionKey
            case .loiterRadius: return .loiterRadiusKey
            }
        }

        /// All values to allow enumerating settings
        static let allCases: [Setting] = [
            .maxPitchRoll(0, 0, 0),
            .maxHorizontalSpeed(0, 0, 0),
            .speedMode(.normal),
            .maxPitchRollVelocity(0, 0, 0),
            .maxVerticalSpeed(0, 0, 0),
            .maxYawRotationSpeed(0, 0, 0),
            .takeoffHoveringAltitude(0, 0, 0),
            .bankedTurnMode(false),
            .motionDetectionMode(false),
            .vehicleType(nil),
            .assistanceMode(.assistedAttitude),
            .loiterShape(.circle),
            .loiterDirection(.clockwise),
            .loiterRadius(0, 0, 0)
        ]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case speedMode(Set<SpeedMode>)
        case assistanceMode(Set<AssistanceMode>)
        case loiterShape(Set<LoiterShape>)
        case loiterDirection(Set<LoiterDirection>)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [.speedMode([])]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .speedMode: return .speedModeKey
            case .assistanceMode: return .assistanceModeKey
            case .loiterShape: return .loiterShapeKey
            case .loiterDirection: return .loiterDirectionKey
            }
        }
    }

    /// Setting values as received from the drone
    internal var droneSettings = Set<Setting>()

    /// Constructor
    ///
    /// - Parameter droneController: drone controller owning this component
    override init(activationController: PilotingItfActivationController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = activationController.droneController.deviceStore.getSettingsStore(
                key: ManualCopterPilotingItfController.settingKey)
            presetStore = activationController.droneController.presetStore.getSettingsStore(
                key: ManualCopterPilotingItfController.settingKey)
        }
        super.init(activationController: activationController)
        arsdkPilotingDecoder = ArsdkPilotingEventDecoder(listener: self)
        arsdkLoiterDecoder = ArsdkLoiterEventDecoder(listener: self)

        manualCopterPilotingItf = ManualCopterPilotingItfCore(store: droneController.drone.pilotingItfStore,
                                                 backend: self)
        manualPlanePilotingItf = ManualPlanePilotingItfCore(store: droneController.drone.pilotingItfStore,
                                                 backend: self)
        prepareOfflineSettings()
        pilotingItf = manualCopterPilotingItf

        loadPresets()
        if isPersisted {
            pilotingItf.publish()
            if self.vehicleType == .vtol {
                manualPlanePilotingItf.publish()
            }
        }
    }

    func set(pitch: Int) {
        setPitch(pitch)
    }

    func set(roll: Int) {
        setRoll(roll)
    }

    func set(yawRotationSpeed: Int) {
        setYaw(yawRotationSpeed)
    }

    func set(verticalSpeed: Int) {
        setGaz(verticalSpeed)
    }

    func set(throttle: Int) {
        setGaz(throttle)
    }

    func hover() {
        setRoll(0)
        setPitch(0)
    }

    /// Send takeoff request
    final func takeOff() {
        if connected {
            sendTakeOffCommand()
        }
    }

    /// Send land request
    final func land() {
        if connected {
            sendLandCommand()
        }
    }

    /// Send take off request
    final func thrownTakeOff() {
        if connected {
            sendThrownTakeOffCommand()
        }
    }

    /// Send emergency request
    final func emergencyCutOut() {
        if connected {
            sendEmergencyCutOutCommand()
        }
    }

    /// Send arm request
    final func arm() {
        if connected {
            sendTakeOffCommand()
        }
    }

    /// Send cancel arming request
    final func cancelArming() {
        if connected {
            sendTakeOffCommand()
        }
    }

    override func activate() -> Bool {
        if vehicleType == .vtol {
            return sendStartFlightModeCommand(.manualCopter)
        } else {
            return super.activate()
        }
    }

    /// Send start or stop loiter request
    ///
    /// - Parameter loitering: whether to start loitering or not.
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func start(loitering: Bool) -> Bool {
        if connected {
            return sendStartFlightModeCommand(loitering ? .loiter : .manualPlane)
        }
        return false
    }

    /// Send assistance mode settings
    ///
    /// - Parameter assistanceMode: new assistance mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(assistanceMode value: AssistanceMode) -> Bool {
        guard let manualPlanePilotingItf else { return false }

        guard !backupLinkIsActive else {
            manualPlanePilotingItf.forceNotifyUpdated()
            return false
        }
        return assistanceModeSetting!.setValue(value: value)
    }

    /// Configure loiter shape
    ///
    /// - Parameter loiterShape: the new loiter shape.
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(loiterShape: LoiterShape) -> Bool {
        guard let manualPlanePilotingItf else { return false }

        guard !backupLinkIsActive else {
            manualPlanePilotingItf.forceNotifyUpdated()
            return false
        }
        return loiterShapeSetting!.setValue(value: loiterShape)
    }

    /// Configure loiter direction
    ///
    /// - Parameter loiterDirection: the new loiter direction.
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(loiterDirection: LoiterDirection) -> Bool {

        guard let manualPlanePilotingItf else { return false }

        guard !backupLinkIsActive else {
            manualPlanePilotingItf.forceNotifyUpdated()
            return false
        }
        return loiterDirectionSetting!.setValue(value: loiterDirection)
    }

    /// Configure loiter radius
    ///
    /// - Parameter loiterRadius: the new loiter radius.
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(loiterRadius: Double) -> Bool {
        guard let manualPlanePilotingItf else { return false }

        guard !backupLinkIsActive else {
            manualPlanePilotingItf.forceNotifyUpdated()
            return false
        }

        return loiterRadiusSetting!.setValue(value: loiterRadius)
    }

    /// Send max pitch/roll settings
    ///
    /// - Parameter maxPitchRoll: new maximum pitch/roll
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxPitchRoll value: Double) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.maxPitchRollKey, value: value).commit()
        if connected {
            sendMaxPitchRollCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxPitchRoll: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send max horizontal speed
    ///
    /// - Parameter maxHorizontalSpeed: new maximum horizontal speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxHorizontalSpeed value: Double) -> Bool {

        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }
        presetStore?.write(key: SettingKey.maxHorizontalSpeedKey, value: value).commit()
        if connected {
            sendMaxHorizontalSpeedCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxHorizontalSpeed: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send max pitch/roll velocity settings
    ///
    /// - Parameter maxPitchRollVelocity: new maximum pitch/roll velocity
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxPitchRollVelocity value: Double) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.maxPitchRollVelocityKey, value: value).commit()
        if connected {
            sendMaxPitchRollVelocityCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxPitchRollVelocity: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send max vertical speed settings
    ///
    /// - Parameter maxVerticalSpeed: new maximum vertical speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxVerticalSpeed value: Double) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.maxVerticalSpeedKey, value: value).commit()
        if connected {
            sendMaxVerticalSpeedCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxVerticalSpeed: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send speed mode settings
    ///
    /// - Parameter speedMode: new speed mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(speedMode value: SpeedMode) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.speedModeKey, value: value).commit()
        if connected {
            sendSpeedModeCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(speedMode: value).notifyUpdated()
            return false
        }
    }

    final func set(takeoffHoveringAltitude: Double) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }
        presetStore?.write(key: SettingKey.takeoffHoveringAltitudeKey, value: takeoffHoveringAltitude).commit()
        if connected {
            sendTakeoffHoveringAltitude(takeoffHoveringAltitude)
            return true
        } else {
            manualCopterPilotingItf.update(takeoffHoveringAltitude: (nil, takeoffHoveringAltitude, nil)).notifyUpdated()
            manualPlanePilotingItf.update(takeoffHoveringAltitude: (nil, takeoffHoveringAltitude, nil)).notifyUpdated()
            return false
        }
    }

    /// Send max yaw rotation speed settings
    ///
    /// - Parameter maxYawRotationSpeed: new maximum yaw rotation speed
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(maxYawRotationSpeed value: Double) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            manualPlanePilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.maxYawRotationSpeedKey, value: value).commit()
        if connected {
            sendMaxYawRotationSpeedCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(maxYawRotationSpeed: (nil, value, nil)).notifyUpdated()
            manualPlanePilotingItf.update(maxYawRotationSpeed: (nil, value, nil)).notifyUpdated()
            return false
        }
    }

    /// Send banked-turn mode settings
    ///
    /// - Parameter bankedTurnMode: new banked turn mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(bankedTurnMode value: Bool) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.bankedTurnModeKey, value: value).commit()
        if connected {
            sendBankedTurnModeCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(bankedTurnMode: value).notifyUpdated()
            return false
        }
    }

    /// Send motion detection mode settings
    ///
    /// - Parameter useThrownTakeOffForSmartTakeOff: will set the corresponding motionDetection mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(useThrownTakeOffForSmartTakeOff value: Bool) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }

        presetStore?.write(key: SettingKey.motionDetectionModeKey, value: value).commit()
        if connected {
            sendMotionDetectionModeCommand(value)
            return true
        } else {
            manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value).notifyUpdated()
            return false
        }
    }

    /// Send preferred ATTI mode settings
    ///
    /// - Parameter preferredAttiMode: new preferred ATTI mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    final func set(preferredAttiMode value: Bool) -> Bool {
        guard !backupLinkIsActive else {
            manualCopterPilotingItf.forceNotifyUpdated()
            return false
        }
        if connected {
            sendPreferredAttiModeCommand(value)
            return true
        }
        return false
    }

    /// Send takeoff command. Subclass must override this function to send the drone specific command
    func sendTakeOffCommand() { }
    /// Send thrownTakeoff command. Subclass must override this function to send the drone specific command
    func sendThrownTakeOffCommand() { }
    /// Send land command. Subclass must override this function to send the drone specific command
    func sendLandCommand() { }
    /// Send emergency cut-out command. Subclass must override this function to send the drone specific command
    func sendEmergencyCutOutCommand() { }
    /// Send set max pitch/roll command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMaxPitchRollCommand(_ value: Double) { }
    /// Send set max horizontal speed command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMaxHorizontalSpeedCommand(_ value: Double) { }
    /// Send set speed mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendSpeedModeCommand(_ value: SpeedMode) { }
    /// Send set vehicle mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendVehicleMode(_ value: VehicleMode) { }
    /// Send set take off hovering altitude command. Subclass must override this function to send the drone specific
    /// command
    ///
    /// - Parameter value: new value
    func sendTakeoffHoveringAltitude(_ value: Double) { }
    /// Send set max pitch/roll velocity command. Subclass must override this function to send the drone specific
    /// command
    ///
    /// - Parameter value: new value
    func sendMaxPitchRollVelocityCommand(_ value: Double) { }
    /// Send set max vertical speed command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMaxVerticalSpeedCommand(_ value: Double) { }
    /// Send set max yaw rotation speed command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMaxYawRotationSpeedCommand(_ value: Double) { }
    /// Send set banked turn mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendBankedTurnModeCommand(_ value: Bool) { }
    /// Send set motion detection mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendMotionDetectionModeCommand(_ value: Bool) { }

    /// Send preferred ATTI mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendPreferredAttiModeCommand(_ value: Bool) { }

    /// Send assistance mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendAssistanceModeCommand(_ value: AssistanceMode) -> Bool { return false }

    /// Send start piloting mode command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameter value: new value
    func sendStartFlightModeCommand(_ value: Arsdk_Piloting_FlightMode) -> Bool { return false }

    /// Send loiter shape command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameters:
    ///    - shape: new shape
    func sendLoiterShapeCommand(_ value: LoiterShape) -> Bool { return false }

    /// Send loiter direction command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameters:
    ///    - direction: new direction
    func sendLoiterDirectionCommand(_ value: LoiterDirection) -> Bool { return false }

    /// Send loiter radius command. Subclass must override this function to send the drone specific command
    ///
    /// - Parameters:
    ///    - radius: new radius
    func sendLoiterRadiusCommand(_ value: Double) -> Bool { return false }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        super.willForget()
    }

    /// Drone is about to be connect
    override func willConnect() {
        super.willConnect()
        // remove settings stored while connecting. We will get new one on the next connection.
        settings.forEach { setting in
            setting.resetDeviceValue()
        }
        // remove settings stored while connecting. We will get new one on the next connection.
        droneSettings.removeAll()
        _ = sendGetPilotingCapabilitiesCommand()
        _ = sendGetPilotingStateCommand()
    }

    /// Drone is connected
    override func didConnect() {
        storeNewPresets()
        applyPresets()
        super.didConnect()
        // it needs to be refreshed in case we are receiving the state before the connection.
        if vehicleType == .vtol {
            updatePilotingItf()
        }
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        pilotingItf.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        // clear all non saved settings
        manualCopterPilotingItf.cancelSettingsRollback().update(canLand: false).update(canTakeOff: false)
            .update(smartWillThrownTakeoff: false)
            .update(currentAttiMode: nil)
            .update(preferredAttiMode: nil)

        manualPlanePilotingItf.cancelSettingsRollback().update(takeoffState: nil)

        if !isPersisted {
            manualCopterPilotingItf.unpublish()
            manualPlanePilotingItf.unpublish()
        }

        // super will call notifyUpdated
        super.didDisconnect()

        manualPlanePilotingItf.update(activeState: .unavailable).notifyUpdated()
        manualCopterPilotingItf.update(activeState: .unavailable).notifyUpdated()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()

        // reload preset store
        if connected {
            settings.forEach { setting in
                setting.applyPreset()
            }
        }
        // reload preset store
        presetStore = activationController.droneController.presetStore.getSettingsStore(
            key: ManualCopterPilotingItfController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    public func prepareOfflineSettings() {
        assistanceModeSetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.assistanceModeKey,
            setting: manualPlanePilotingItf.assistanceMode as! EnumSettingCore,
            notifyComponent: {
            self.manualPlanePilotingItf.notifyUpdated()
            }, markChanged: {
                self.manualPlanePilotingItf.markChanged()
            }, sendCommand: { assistanceMode in
                self.sendAssistanceModeCommand(assistanceMode)
            })

        loiterShapeSetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.loiterShapeKey,
            setting: manualPlanePilotingItf.loiterShape as! EnumSettingCore,
            notifyComponent: {
                self.manualPlanePilotingItf.notifyUpdated()
            }, markChanged: {
                self.manualPlanePilotingItf.markChanged()
            }, sendCommand: { shape in
                self.sendLoiterShapeCommand(shape)
            })

        loiterDirectionSetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.loiterDirectionKey,
            setting: manualPlanePilotingItf.loiterDirection as! EnumSettingCore,
            notifyComponent: {
                self.manualPlanePilotingItf.notifyUpdated()
            }, markChanged: {
                self.manualPlanePilotingItf.markChanged()
            }, sendCommand: { direction in
                self.sendLoiterDirectionCommand(direction)
            })

        loiterRadiusSetting = OfflineDoubleSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.loiterRadiusKey,
            setting: manualPlanePilotingItf.loiterRadius as! DoubleSettingCore,
            notifyComponent: {
                self.manualPlanePilotingItf.notifyUpdated()
            }, markChanged: {
                self.manualPlanePilotingItf.markChanged()
            }, sendCommand: { radius in
                self.sendLoiterRadiusCommand(radius)
            }
        )
        settings = [assistanceModeSetting!, loiterShapeSetting!, loiterDirectionSetting!, loiterRadiusSetting!]
    }

    /// Load saved settings into pilotingItf
    private func loadPresets() {
        for setting in Setting.allCases {
            switch setting {
            case .maxPitchRoll:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxPitchRoll: (range.min, value, range.max))
                }
            case .maxHorizontalSpeed:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxHorizontalSpeed: (range.min, value, range.max))
                }
            case .speedMode:
                if let deviceStore = deviceStore, let presetStore = presetStore {
                    if let value: SpeedMode = presetStore.read(key: setting.key),
                        let supportedSpeedModes: StorableArray<SpeedMode> = deviceStore.read(key: setting.key) {
                        manualCopterPilotingItf.update(supportedSpeedModes: Set(supportedSpeedModes.storableValue))
                            .update(speedMode: value)
                    }
                }
            case .maxPitchRollVelocity:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxPitchRollVelocity: (range.min, value, range.max))
                }
            case .maxVerticalSpeed:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxVerticalSpeed: (range.min, value, range.max))
                }
            case .maxYawRotationSpeed:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(maxYawRotationSpeed: (range.min, value, range.max))
                    manualPlanePilotingItf.update(maxYawRotationSpeed: (range.min, value, range.max))
                }
            case .bankedTurnMode:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Bool = presetStore.read(key: setting.key) {
                        manualCopterPilotingItf.update(bankedTurnMode: value)
                    }
                }
            case .motionDetectionMode:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   deviceStore.readSupportedFlag(key: setting.key) {
                    if let value: Bool = presetStore.read(key: setting.key) {
                        manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value)
                    }
                }
            case .takeoffHoveringAltitude:
                if let deviceStore = deviceStore, let presetStore = presetStore,
                   let value: Double = presetStore.read(key: setting.key),
                   let range: (min: Double, max: Double) = deviceStore.readRange(key: setting.key) {
                    manualCopterPilotingItf.update(takeoffHoveringAltitude: (range.min, value, range.max))
                    manualPlanePilotingItf.update(takeoffHoveringAltitude: (range.min, value, range.max))
                }
            case .vehicleType:
                if let deviceStore {
                    if let value: VehicleType = deviceStore.read(key: setting.key) {
                        vehicleType = value
                        // Init doesn't called the didSet from vehicleType, it needs to be called manually.
                        updatePilotingItf()
                    }
                }
            case .assistanceMode:
                break
            case .loiterShape:
                break
            case .loiterDirection:
                break
            case .loiterRadius:
                break
            }
        }
        pilotingItf.notifyUpdated()
    }

    /// Called when the drone is connected, save all settings received during the connection and  not yet in the preset
    /// store, and all received settings ranges
    private func storeNewPresets() {
        if let deviceStore = deviceStore {
            for setting in droneSettings {
                switch setting {
                case let .maxPitchRoll(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxHorizontalSpeed(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxPitchRollVelocity(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxVerticalSpeed(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case let .maxYawRotationSpeed(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .bankedTurnMode:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case .motionDetectionMode:
                    deviceStore.writeSupportedFlag(key: setting.key)
                case let .takeoffHoveringAltitude(min, _, max):
                    deviceStore.writeRange(key: setting.key, min: min, max: max)
                case .speedMode:
                    break
                case .vehicleType:
                    break
                case .assistanceMode:
                    break
                case .loiterShape:
                    break
                case .loiterDirection:
                    break
                case .loiterRadius:
                    break
                }
            }
            deviceStore.commit()
        }
    }

    /// Apply a presets
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case let .maxPitchRoll(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxPitchRollCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxPitchRoll: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxPitchRoll: (min: min, value: value, max: max))
                }
            case let .maxHorizontalSpeed(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxHorizontalSpeedCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxHorizontalSpeed: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxHorizontalSpeed: (min: min, value: value, max: max))
                }
            case let .speedMode(value):
                if let preset: SpeedMode = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendSpeedModeCommand(preset)
                    }
                    manualCopterPilotingItf.update(speedMode: preset)
                } else {
                    manualCopterPilotingItf.update(speedMode: value)
                }
            case let .maxPitchRollVelocity(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxPitchRollVelocityCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxPitchRollVelocity: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxPitchRollVelocity: (min: min, value: value, max: max))
                }
            case let .maxVerticalSpeed(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxVerticalSpeedCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxVerticalSpeed: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxVerticalSpeed: (min: min, value: value, max: max))
                }
            case let .maxYawRotationSpeed(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMaxYawRotationSpeedCommand(preset)
                    }
                    manualCopterPilotingItf.update(maxYawRotationSpeed: (min: min, value: preset, max: max))
                    manualPlanePilotingItf.update(maxYawRotationSpeed: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(maxYawRotationSpeed: (min: min, value: value, max: max))
                    manualPlanePilotingItf.update(maxYawRotationSpeed: (min: min, value: value, max: max))
                }
            case let .bankedTurnMode(value):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendBankedTurnModeCommand(preset)
                    }
                    manualCopterPilotingItf.update(bankedTurnMode: preset)
                } else {
                    manualCopterPilotingItf.update(bankedTurnMode: value)
                }
            case let .motionDetectionMode(value):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendMotionDetectionModeCommand(preset)
                    }
                    manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: preset)
                } else {
                    manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value)
                }
            case let .takeoffHoveringAltitude(min, value, max):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != value {
                        sendTakeoffHoveringAltitude(preset)
                    }
                    manualCopterPilotingItf.update(takeoffHoveringAltitude: (min: min, value: preset, max: max))
                    manualPlanePilotingItf.update(takeoffHoveringAltitude: (min: min, value: preset, max: max))
                } else {
                    manualCopterPilotingItf.update(takeoffHoveringAltitude: (min: min, value: value, max: max))
                    manualPlanePilotingItf.update(takeoffHoveringAltitude: (min: min, value: value, max: max))
                }
            case .vehicleType:
                break
            case .assistanceMode:
                break
            case .loiterShape:
               break
            case .loiterDirection:
                break
            case .loiterRadius:
                break
            }
        }
        pilotingItf.notifyUpdated()
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        // collect received settings
        droneSettings.insert(setting)
        // apply setting if connected
        if connected {
            switch setting {
            case let .maxPitchRoll(min, value, max):
                manualCopterPilotingItf.update(maxPitchRoll: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .maxHorizontalSpeed(min, value, max):
                manualCopterPilotingItf.update(maxHorizontalSpeed: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .speedMode(value):
                manualCopterPilotingItf.update(speedMode: value)
            case let .maxPitchRollVelocity(min, value, max):
                manualCopterPilotingItf.update(maxPitchRollVelocity: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .maxVerticalSpeed(min, value, max):
                manualCopterPilotingItf.update(maxVerticalSpeed: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .maxYawRotationSpeed(min, value, max):
                manualCopterPilotingItf.update(maxYawRotationSpeed: (min: min, value: value, max: max))
                manualPlanePilotingItf.update(maxYawRotationSpeed: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case let .bankedTurnMode(value):
                manualCopterPilotingItf.update(bankedTurnMode: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .motionDetectionMode(value):
                manualCopterPilotingItf.update(useThrownTakeOffForSmartTakeOff: value)
                deviceStore?.writeSupportedFlag(key: setting.key)
            case let .takeoffHoveringAltitude(min, value, max):
                manualCopterPilotingItf.update(takeoffHoveringAltitude: (min: min, value: value, max: max))
                manualPlanePilotingItf.update(takeoffHoveringAltitude: (min: min, value: value, max: max))
                deviceStore?.writeRange(key: setting.key, min: min, max: max)
            case .vehicleType:
                break
            case .assistanceMode:
                break
            case .loiterShape:
                break
            case .loiterDirection:
                break
            case .loiterRadius:
                break

            }
            pilotingItf.notifyUpdated()
            deviceStore?.commit()
        }
    }

    /// Called when a command that notify a capabilities change has been received
    ///
    /// - Parameter capabilities: capabilities that changed
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .speedMode(let speedModes):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(speedModes)))
            manualCopterPilotingItf.update(supportedSpeedModes: speedModes)
        case .assistanceMode:
            break
        case .loiterShape:
            break
        case .loiterDirection:
            break
        }
        pilotingItf.notifyUpdated()
        deviceStore?.commit()
    }

    /// Sends get piloting state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetPilotingStateCommand() -> Bool {
        return sendPilotingCommand(.getState(Google_Protobuf_Empty()))
    }

    /// Sends get piloting capabilities command.
    func sendGetPilotingCapabilitiesCommand() -> Bool {
        return sendPilotingCommand(.getCapabilities(Google_Protobuf_Empty()))
    }

    /// Sends get loiter state command.
    func sendGetLoiterStateCommand() -> Bool {
        var state = Arsdk_Loiter_Command.GetState()
        state.includeDefaultCapabilities = true

        return sendLoiterCommand(.getState(state))
    }

    /// Sends to the device a Piloting command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendPilotingCommand(_ command: Arsdk_Piloting_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkPilotingCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends to the device a Navigation command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendNavigationCommand(_ command: Arsdk_Navigation_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkNavigationCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends to the device a Loiter command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendLoiterCommand(_ command: Arsdk_Loiter_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkLoiterCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension to make SpeedMode storable.
extension SpeedMode: StorableEnum {
    static let storableMapper = Mapper<SpeedMode, String>([
        .normal: "normal",
        .low: "low"])
}

/// Extension that adds conversion from/to arsdk enum.
extension SpeedMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<SpeedMode, Arsdk_Piloting_SpeedMode>([
        .normal: .normalSpeedMode,
        .low: .lowSpeedMode
    ])
}

/// Extension to make VehicleType storable.
extension VehicleType: StorableEnum {
    static let storableMapper = Mapper<VehicleType, String>([
        .multicopter: "multicopter",
        .helicopter: "helicopter",
        .vtol: "vtol",
        .plane: "plane"])
}

/// Extension that adds conversion from/to arsdk enum.
extension VehicleType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<VehicleType, Arsdk_Piloting_VehicleType>([
        .multicopter: .multicopter,
        .helicopter: .helicopter,
        .vtol: .vtol,
        .plane: .plane
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension AssistanceMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<AssistanceMode, Arsdk_Piloting_AssistanceMode>([
        .assistedAltitude: .assistedAltitude,
        .assistedAttitude: .assistedAttitude
    ])
}

/// Extension to make AssistanceMode storable.
extension AssistanceMode: StorableEnum {
    static let storableMapper = Mapper<AssistanceMode, String>([
        .assistedAltitude: "assistedAltitude",
        .assistedAttitude: "assistedAttitude"])
}

/// Extension that adds conversion from/to arsdk enum.
extension TakeoffState: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<TakeoffState, Arsdk_Piloting_TakeoffState>([
        .idle: .idle,
        .arming: .arming,
        .ready: .ready,
        .rescue: .rescue
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension LoiterShape: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<LoiterShape, Arsdk_Loiter_Shape>([
        .circle: .circle,
        .eight: .eight
    ])
}

/// Extension to make LoiterShape storable.
extension LoiterShape: StorableEnum {
    static let storableMapper = Mapper<LoiterShape, String>([
        .circle: "circle",
        .eight: "eight"])
}

/// Extension that adds conversion from/to arsdk enum.
extension LoiterDirection: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<LoiterDirection, Arsdk_Loiter_Direction>([
        .clockwise: .clockwise,
        .counterClockwise: .counterClockwise
    ])
}

/// Extension to make LoiterDirection storable.
extension LoiterDirection: StorableEnum {
    static let storableMapper = Mapper<LoiterDirection, String>([
        .clockwise: "clockwise",
        .counterClockwise: "counterClockwise"])
}
