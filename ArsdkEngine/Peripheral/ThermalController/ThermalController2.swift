// Copyright (C) 2026 Parrot Drones SAS
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

/// Base controller for thermal control 2 peripheral
class ThermalController2: DeviceComponentController, ThermalControl2CoreBackend {
    /// Thermal controller 2 component
    private var thermalControl: ThermalControl2Core!

    /// Component settings key
    private static let settingKey = "ThermalControl2"

    /// Preset store for this thermal controller 2 interface
    private var presetStore: SettingsStore?

    /// Device store for this thermal controller 2 interface
    private var deviceStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// Decoder for thermal control events.
    private var thermalControlDecoder: ArsdkThermalcontrolEventDecoder!

    /// Decoder for camera events.
    private var cameraDecoder: ArsdkCameraEventDecoder!

    /// Power saving mode setting backend
    internal var powerSavingModeSetting: OfflineEnumSetting<ThermalPowerSavingMode>!

    /// Rendering mixing mode setting backend
    internal var mixingModeSetting: OfflineEnumSetting<ThermalMixingMode>!

    /// Rendering edge coefficient setting backend
    internal var edgeCoefficientSetting: OfflineDoubleSetting!

    /// Rendering minimum colorization threshold setting backend
    internal var minColorizationThresholdSetting: OfflineDoubleSetting!

    /// Rendering maximum colorization threshold setting backend
    internal var maxColorizationThresholdSetting: OfflineDoubleSetting!

    /// Rendering range locked setting backend
    internal var rangeLockedSetting: OfflineBoolSetting!

    /// Whether the palette has been received or not
    private var hasReceivedPalette = false

    /// All setting backends of this peripheral
    private var settings = [OfflineSetting]()

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case powerSavingModeKey = "powerSavingMode"
        case mixingModeKey = "mixingMode"
        case edgeCoefficientKey = "edgeCoefficient"
        case minColorizationThresholdKey = "minColorizationThreshold"
        case maxColorizationThresholdKey = "maxColorizationThreshold"
        case rangeLockedKey = "rangeLocked"
        case paletteKey = "palette"
    }

    /// Stored settings
    enum Setting: Hashable {
        case palette(ThermalPalette2)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .palette: return .paletteKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [.palette(ThermalPalette2(colors: [ThermalColor]()))]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: ThermalController2.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: ThermalController2.settingKey)
        }
        super.init(deviceController: deviceController)
        thermalControl = ThermalControl2Core(store: deviceController.device.peripheralStore, backend: self)
        thermalControlDecoder = ArsdkThermalcontrolEventDecoder(listener: self)
        cameraDecoder = ArsdkCameraEventDecoder(listener: self)
        prepareOfflineSettings()
        loadPresets()
        if isPersisted {
            thermalControl.publish()
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore {
            for setting in Setting.allCases {
                switch setting {
                case .palette:
                    if let palette: ThermalPalette2 = presetStore.read(key: setting.key) {
                        thermalControl.update(palette: palette)
                    }
                }
                thermalControl.notifyUpdated()
            }
        }
    }

    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .palette(let palette):
                if let preset: ThermalPalette2 = presetStore?.read(key: setting.key) {
                    if preset.colors != palette.colors {
                        _ = sendPaletteCommand(palette: preset)
                    }
                    thermalControl.update(palette: preset)

                } else {
                    thermalControl.update(palette: palette)
                }
            }
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        if hasReceivedPalette && connected {
            switch setting {
            case .palette(let palette):
                thermalControl.update(palette: palette).notifyUpdated()
            }
        }
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: ThermalController2.settingKey)
        loadPresets()
        if connected {
            settings.forEach { setting in
                setting.applyPreset()
            }
            applyPresets()
        }
    }

    /// Prepare offline settings
    private func prepareOfflineSettings() {
        powerSavingModeSetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.powerSavingModeKey,
            setting: thermalControl.powerSavingMode as! EnumSettingCore,
            notifyComponent: {
            self.thermalControl.notifyUpdated()
            }, markChanged: {
                self.thermalControl.markChanged()
            }, sendCommand: { powerSavingMode in
                self.sendPowerSavingModeCommand(powerSavingMode)
        })

        mixingModeSetting = OfflineEnumSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.mixingModeKey,
            setting: thermalControl.mixingMode as! EnumSettingCore,
            notifyComponent: {
            self.thermalControl.notifyUpdated()
            }, markChanged: {
                self.thermalControl.markChanged()
            }, sendCommand: { mixingMode in
                self.sendMixingModeCommand(mixingMode)
        })

        edgeCoefficientSetting = OfflineDoubleSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.edgeCoefficientKey,
            setting: thermalControl.edgeCoefficient as! DoubleSettingCore,
            notifyComponent: {
                self.thermalControl.notifyUpdated()
            }, markChanged: {
                self.thermalControl.markChanged()
            }, sendCommand: { edgeCoefficient in
                self.sendEdgeCoefficientCommand(edgeCoefficient)
            }
        )

        minColorizationThresholdSetting = OfflineDoubleSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.minColorizationThresholdKey,
            setting: thermalControl.minColorizationThreshold as! DoubleSettingCore,
            notifyComponent: {
                self.thermalControl.notifyUpdated()
            }, markChanged: {
                self.thermalControl.markChanged()
            }, sendCommand: { min in
                self.sendMinColorizationThresholdCommand(min)
            }
        )

        maxColorizationThresholdSetting = OfflineDoubleSetting(
            deviceDict: deviceStore, presetDict: presetStore,
            entry: SettingKey.maxColorizationThresholdKey,
            setting: thermalControl.maxColorizationThreshold as! DoubleSettingCore,
            notifyComponent: {
                self.thermalControl.notifyUpdated()
            }, markChanged: {
                self.thermalControl.markChanged()
            }, sendCommand: { max in
                self.sendMaxColorizationThresholdCommand(max)
            }
        )

        rangeLockedSetting = OfflineBoolSetting(
            presetDict: presetStore, presetEntry: SettingKey.rangeLockedKey,
            setting: thermalControl.rangeLocked as! BoolSettingCore,
            notifyComponent: {
                self.thermalControl.notifyUpdated()
            }, markChanged: {
                self.thermalControl.markChanged()
            }, sendCommand: { locked in
                self.sendRangeLockedCommand(locked)
            })

        settings = [powerSavingModeSetting, mixingModeSetting, edgeCoefficientSetting,
                    minColorizationThresholdSetting, maxColorizationThresholdSetting, rangeLockedSetting]
    }

    /// Drone is about to be connected.
    override func willConnect() {
        hasReceivedPalette = false
        // remove settings stored while connecting; we will get new one on next connection
        settings.forEach { setting in
            setting.resetDeviceValue()
        }
        droneSettings.removeAll()
        _ = sendGetThermalControlStateCommand()
        _ = sendGetThermalControlCapabilitiesCommand()
    }

    /// Drone is connected
    override func didConnect() {
        applyPresets()
        super.didConnect()
    }

    /// Drone did disconnect
    override func didDisconnect() {
        thermalControl.cancelSettingsRollback()
        if isPersisted {
            thermalControl.notifyUpdated()
        } else {
            thermalControl.unpublish()
        }
    }

    /// Drone is about to be forgotten.
    override func willForget() {
        deviceStore?.clear()
        thermalControl.unpublish()
        super.willForget()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        thermalControlDecoder.decode(command)
        cameraDecoder.decode(command)
    }

    func calibrate() -> Bool {
        let command = Arsdk_Thermalcontrol_Command.StartUniformityCalibration()
        return sendThermalControlCommand(.startCalibration(command))
    }

    func abortCalibration() -> Bool {
        let command = Arsdk_Thermalcontrol_Command.AbortUniformityCalibration()
        return sendThermalControlCommand(.abortCalibration(command))
    }

    func confirmUserAction() -> Bool {
        let command = Arsdk_Thermalcontrol_Command.ConfirmUniformityCalibrationUserAction()
        return sendThermalControlCommand(.userCalibration(command))
    }

    func set(powerSavingMode: ThermalPowerSavingMode) -> Bool {
        return powerSavingModeSetting.setValue(value: powerSavingMode) == true
    }

    func set(calibrationMode: ThermalCalibrationMode) -> Bool {
        // nothing to do
        return false
    }

    func set(palette: ThermalPalette2) -> Bool {
        // save palette in presetStore
        presetStore?.write(key: SettingKey.paletteKey, value: palette).commit()
        if connected {
            return sendPaletteCommand(palette: palette)
        } else {
            thermalControl.update(palette: palette)
            return false
        }
    }

    func set(mixingMode: ThermalMixingMode) -> Bool {
        return mixingModeSetting.setValue(value: mixingMode) == true
    }

    func set(edgeCoefficient: Double) -> Bool {
        return edgeCoefficientSetting.setValue(value: edgeCoefficient) == true
    }

    func set(minColorizationThreshold: Double) -> Bool {
        return minColorizationThresholdSetting.setValue(value: minColorizationThreshold) == true
    }

    func set(maxColorizationThreshold: Double) -> Bool {
        return maxColorizationThresholdSetting.setValue(value: maxColorizationThreshold) == true
    }

    func set(rangeLocked: Bool) -> Bool {
        return rangeLockedSetting.setValue(value: rangeLocked) == true
    }

    /// Send power saving mode command.
    ///
    /// - Parameter mode: requested power saving mode.
    /// - Returns: true if the command has been sent
    func sendPowerSavingModeCommand(_ mode: ThermalPowerSavingMode) -> Bool {
        var setMode = Arsdk_Thermalcontrol_Command.SetPowerSaving()
        if let mode = Arsdk_Thermalcontrol_PowerSavingMode(rawValue: mode.rawValue) {
            setMode.mode = mode
            if let encoder = ArsdkThermalcontrolCommandEncoder.encoder(.setPowerSaving(setMode)) {
                return sendCommand(encoder)
            }
        }
        return false
    }

    /// Send rendering range locked command.
    ///
    /// - Parameter value: requested range locked
    /// - Returns: true if the command has been sent
    func sendRangeLockedCommand(_ value: Bool) -> Bool {
        var rendering = Arsdk_Thermalrendering_Rendering()
        var valueToSend = Google_Protobuf_BoolValue()
        valueToSend.value = value
        rendering.rangeLocked = valueToSend
        var cameraCommand = Arsdk_Camera_Command.SetThermalRendering()
        cameraCommand.rendering = rendering
        return sendCameraCommand(.setThermalRendering(cameraCommand))
    }

    /// Send rendering mixing mode command.
    ///
    /// - Parameter value: requested mixing mode
    /// - Returns: true if the command has been sent
    func sendMixingModeCommand(_ value: ThermalMixingMode) -> Bool {
        var rendering = Arsdk_Thermalrendering_Rendering()
        if let newMixingMode = value.arsdkValue {
            var valueToSend = Arsdk_Thermalrendering_MixingModeValue()
            valueToSend.value = newMixingMode
            rendering.mixingMode = valueToSend
            var cameraCommand = Arsdk_Camera_Command.SetThermalRendering()
            cameraCommand.rendering = rendering
            return sendCameraCommand(.setThermalRendering(cameraCommand))
        }
        return false
    }

    /// Send rendering edge coefficient command.
    ///
    /// - Parameter value: requested edge coefficient
    /// - Returns: true if the command has been sent
    func sendEdgeCoefficientCommand(_ value: Double) -> Bool {
        var rendering = Arsdk_Thermalrendering_Rendering()
        var valueToSend = Google_Protobuf_FloatValue()
        valueToSend.value = Float(value)
        rendering.edgeCoef = valueToSend
        var cameraCommand = Arsdk_Camera_Command.SetThermalRendering()
        cameraCommand.rendering = rendering
        return sendCameraCommand(.setThermalRendering(cameraCommand))
    }

    /// Send rendering minimum colorization threshold command.
    ///
    /// - Parameter value: requested minimum colorization threshold
    /// - Returns: true if the command has been sent
    func sendMinColorizationThresholdCommand(_ value: Double) -> Bool {
        var rendering = Arsdk_Thermalrendering_Rendering()
        var valueToSend = Google_Protobuf_FloatValue()
        valueToSend.value = Float(value)
        rendering.minVisibilityThreshold = valueToSend
        var cameraCommand = Arsdk_Camera_Command.SetThermalRendering()
        cameraCommand.rendering = rendering
        return sendCameraCommand(.setThermalRendering(cameraCommand))
    }

    /// Send rendering maximum colorization threshold command.
    ///
    /// - Parameter value: requested maximum colorization threshold
    /// - Returns: true if the command has been sent
    func sendMaxColorizationThresholdCommand(_ value: Double) -> Bool {
        var rendering = Arsdk_Thermalrendering_Rendering()
        var valueToSend = Google_Protobuf_FloatValue()
        valueToSend.value = Float(value)
        rendering.maxVisibilityThreshold = valueToSend
        var cameraCommand = Arsdk_Camera_Command.SetThermalRendering()
        cameraCommand.rendering = rendering
        return sendCameraCommand(.setThermalRendering(cameraCommand))
    }

    /// Send palette command.
    ///
    /// - Parameter value: requested palette
    /// - Returns: true if the command has been sent
    func sendPaletteCommand(palette: ThermalPalette2) -> Bool {
        var setThermalPalette = Arsdk_Camera_Command.SetThermalPalette()
        setThermalPalette.cameraID = 1
        var renderingPalette = Arsdk_Thermalrendering_Palette()
        var elements = [Arsdk_Thermalrendering_PaletteElement]()
        for color in palette.colors {
            var element = Arsdk_Thermalrendering_PaletteElement()
            element.red = Float(color.red)
            element.blue = Float(color.blue)
            element.green = Float(color.green)
            element.position = Float(color.position)
            elements.append(element)
        }
        renderingPalette.paletteElements = elements
        setThermalPalette.palette = renderingPalette
        return sendCameraCommand(.setThermalPalette(setThermalPalette))
    }

    /// Sends thermal control get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetThermalControlStateCommand() -> Bool {
        return sendThermalControlCommand(.getState(Arsdk_Thermalcontrol_Command.GetState()))
    }

    /// Sends thermal control get capabilities command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetThermalControlCapabilitiesCommand() -> Bool {
        return sendThermalControlCommand(.getCapabilities(Arsdk_Thermalcontrol_Command.GetCapabilities()))
    }

    /// Sends to the drone a thermal control command
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendThermalControlCommand(_ command: Arsdk_Thermalcontrol_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkThermalcontrolCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends to the drone a camera command
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCameraCommand(_ command: Arsdk_Camera_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkCameraCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

// Extension for thermal control events processing.
extension ThermalController2: ArsdkThermalcontrolEventDecoderListener {
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
            .update(userActionRequired: calibrationState.requireUserAction).notifyUpdated()
    }

    func onPowerSaving(_ powerSaving: Arsdk_Thermalcontrol_PowerSavingMode) {
        if let mode = ThermalPowerSavingMode(fromArsdk: powerSaving) {
            powerSavingModeSetting.handleNewValue(value: mode)
            thermalControl.notifyUpdated()
        }
    }
}

// Extension for camera events processing.
extension ThermalController2: ArsdkCameraEventDecoderListener {
    func onState(_ state: Arsdk_Camera_Event.State) {
        if state.hasDefaultCapabilities {
            let mixingModes = Set(state.defaultCapabilities.thermalMixingModes
                .compactMap { ThermalMixingMode(fromArsdk: $0) })
            mixingModeSetting.handleNewAvailableValues(values: mixingModes)
            if !state.defaultCapabilities.thermalMixingModes.isEmpty {
                edgeCoefficientSetting.handleNewBounds(min: 0.0, max: 1.0)
                minColorizationThresholdSetting.handleNewBounds(min: 0.0, max: 1.0)
                maxColorizationThresholdSetting.handleNewBounds(min: 0.0, max: 1.0)
            }
        }

        if state.hasThermalRendering {
            if state.thermalRendering.hasEdgeCoef {
                edgeCoefficientSetting.handleNewValue(value: Double(state.thermalRendering.edgeCoef.value))
            }
            if state.thermalRendering.hasMixingMode,
                let mixingMode = ThermalMixingMode(fromArsdk: state.thermalRendering.mixingMode.value) {
                mixingModeSetting.handleNewValue(value: mixingMode)
            }
            if state.thermalRendering.hasRangeLocked {
                rangeLockedSetting.handleNewValue(value: state.thermalRendering.rangeLocked.value)
            }

            if state.thermalRendering.hasMinVisibilityThreshold {
                minColorizationThresholdSetting
                    .handleNewValue(value: Double(state.thermalRendering.minVisibilityThreshold.value))
            }
            if state.thermalRendering.hasMaxVisibilityThreshold {
                maxColorizationThresholdSetting
                    .handleNewValue(value: Double(state.thermalRendering.maxVisibilityThreshold.value))
            }
        }
        if state.hasThermalPalette {
            var colors = [ThermalColor]()
            for paletteElement in state.thermalPalette.paletteElements {
                colors.append(ThermalColor(Double(paletteElement.red), Double(paletteElement.green),
                                           Double(paletteElement.blue), Double(paletteElement.position)))
            }
            settingDidChange(.palette(ThermalPalette2(colors: colors)))
            if !hasReceivedPalette && connected {
                applyPresets()
            }
            hasReceivedPalette = true
        }

        if state.hasThermalRendering || state.hasThermalPalette {
            thermalControl.publish()
        }
    }

    func onCameraExposure(_ cameraExposure: Arsdk_Camera_Event.Exposure) {
        // nothing to do
    }

    func onZoomLevel(_ zoomLevel: Arsdk_Camera_Event.ZoomLevel) {
        // nothing to do
    }

    func onNextPhotoInterval(_ nextPhotoInterval: Arsdk_Camera_Event.NextPhotoInterval) {
        // nothing to do
    }

    func onCameraWhiteBalance(_ cameraWhiteBalance: Arsdk_Camera_Event.WhiteBalance) {
        // nothing to do
    }

    func onCameraList(_ cameraList: Arsdk_Camera_Event.CameraList) {
        // nothing to do
    }

    func onPhoto(_ photo: Arsdk_Camera_Event.Photo) {
        // nothing to do
    }

    func onRecording(_ recording: Arsdk_Camera_Event.Recording) {
        // nothing to do
    }

    func onRequestStreamCamera(_ requestStreamCamera: Arsdk_Camera_StreamCamera) {
        // nothing to do
    }
}

// Extension to make ThermalPalette2 storable
extension ThermalPalette2: StorableType {
    /// Store keys
    private enum Key {
        static let colors = "colors"
    }

    /// Constructor from store data
    ///
    /// - Parameter content: store data
    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
           let colors = StorableArray<ThermalColor>(content[Key.colors]) {
            var storableColors = [ThermalColor]()
            for color in colors.storableValue {
                storableColors.append(color)
            }
            self.init(colors: storableColors)
        } else {
            return nil
        }
    }

    /// Convert data to storable
    ///
    /// - Returns: Storable containing data
    func asStorable() -> StorableProtocol {
        var colorsStorable = [ThermalColor]()
        for color in colors {
            colorsStorable.append(ThermalColor(color.red, color.green, color.blue, color.position))
        }
        return StorableDict<String, AnyStorable>([
            Key.colors: AnyStorable(StorableArray<ThermalColor>(colorsStorable))
        ])
    }
}

// Extension to make ThermalColor storable
extension ThermalColor: StorableType {

    /// Store keys
    private enum Key {
        static let red = "red"
        static let blue = "blue"
        static let green = "green"
        static let position = "position"
    }

    /// Constructor from store data
    ///
    /// - Parameter content: store data
    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
           let red = Double(content[Key.red]),
           let blue = Double(content[Key.blue]),
           let green = Double(content[Key.green]),
           let position = Double(content[Key.position]) {
            self.init(red, green, blue, position)
        } else {
            return nil
        }
    }

    /// Convert data to storable
    ///
    /// - Returns: Storable containing data
    func asStorable() -> StorableProtocol {
        return StorableDict<String, AnyStorable>([
            Key.red: AnyStorable(red),
            Key.green: AnyStorable(green),
            Key.blue: AnyStorable(blue),
            Key.position: AnyStorable(position)
        ])
    }
}

// Extension to make ThermalPowerSavingMode storable
extension ThermalPowerSavingMode: StorableEnum {
    static var storableMapper = Mapper<ThermalPowerSavingMode, String>([
        .alwaysOn: "alwaysOn",
        .hold: "hold",
        .max: "max"])
}

// Extension to make ThermalMixingMode storable
extension ThermalMixingMode: StorableEnum {
    static var storableMapper = Mapper<ThermalMixingMode, String>([
        .blended: "blended",
        .fullThermal: "fullThermal"])
}

// Extension that adds conversion from/to arsdk enum.
extension CalibrationState: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<CalibrationState, Arsdk_Thermalcontrol_UniformityCalibrationStep>([
        .unknown: .UNRECOGNIZED(7),
        .notCalibrated: .notCalibrated,
        .calibrationStarting: .calibrationStarting,
        .waitGimbalCoverOn: .waitGimbalCoverOn,
        .heating: .heating,
        .calibrating: .calibrating,
        .waintGimbalCoverOff: .waitGimbalCoverOff,
        .calibrated: .calibrated
    ])
}

// Extension that adds conversion from/to arsdk enum.
extension ThermalPowerSavingMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<ThermalPowerSavingMode, Arsdk_Thermalcontrol_PowerSavingMode>([
        .alwaysOn: .powerSavingAlwaysOn,
        .hold: .powerSavingHold,
        .max: .powerSavingMax])
}

// Extension that adds conversion from/to arsdk enum.
extension ThermalMixingMode: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<ThermalMixingMode, Arsdk_Thermalrendering_MixingMode>([
        .blended: .blended,
        .fullThermal: .fullThermal])
}
