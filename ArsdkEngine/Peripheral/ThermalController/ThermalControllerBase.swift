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

/// Base controller for thermal control peripheral
class ThermalControllerBase: DeviceComponentController, ThermalControlCoreBackend {

    /// Component settings key
    private static let settingKey = "ThermalControl"

    /// Thermal control component
    private(set) var thermalControl: ThermalControlCore!

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// Latest palette settings sent to drone or latest settings received from drone
    private var currentPaletteSettings: ArsdkThermalPaletteSettings?

    /// Latest palette colors sent to drone or latest colors received from drone
    private var currentColors: [ThermalColor]?

    /// Palette colors being received from drone
    private var paletteParts: [ThermalColor]?

    /// Whether we are expecting the color event
    private var expectingColor: Bool = false

    /// Whether we are expecting the palette event
    private var expectingPalette: Bool = false

    /// Decoder for camera events.
    private var cameraDecoder: ArsdkCameraEventDecoder!

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case modeKey = "mode"
        case sensitivityRangeKey = "sensitivityRange"
        case calibrationModeKey = "calibrationMode"
        case paletteKey = "palette"
        case colorsKey = "colors"
        case backgroundTemperatureKey = "backgroundTemperature"
        case renderingKey = "rendering"
        case emissivitykey = "emissivity"
        case powerSavingModeKey = "powerSavingMode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case mode(ThermalControlMode)
        case sensitivityRange(ThermalSensitivityRange)
        case calibrationMode(ThermalCalibrationMode)
        case palette(ThermalPalette)
        case colors([ThermalColor])
        case backgroundTemperature(Double)
        case rendering(ThermalRendering)
        case emissivity(Double)
        case powerSavingMode(ThermalPowerSavingMode)

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            case .sensitivityRange: return .sensitivityRangeKey
            case .calibrationMode: return .calibrationModeKey
            case .palette: return .paletteKey
            case .colors: return .colorsKey
            case .backgroundTemperature: return .backgroundTemperatureKey
            case .rendering: return .renderingKey
            case .emissivity: return .emissivitykey
            case .powerSavingMode: return .powerSavingModeKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: [Setting] = [.mode(.disabled), .sensitivityRange(.high), .calibrationMode(.automatic),
                                          .palette(ThermalPalette(colors: [ThermalColor](),
                                                                  type: ThermalPaletteType.spot(
                                                                    type: .cold, threshold: 0))),
                                          .backgroundTemperature(0.0),
                                          .rendering(ThermalRendering(mode: .visible, blendingRate: 0.0)),
                                          .emissivity(0.0),
                                          .powerSavingMode(.max)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Stored capabilities for settings
    enum Capabilities {
        case mode(Set<ThermalControlMode>)

        /// All values to allow enumerating settings
        static let allCases: [Capabilities] = [.mode([])]

        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .modeKey
            }
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Constructor
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: ThermalControllerBase.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: ThermalControllerBase.settingKey)
        }

        super.init(deviceController: deviceController)
        cameraDecoder = ArsdkCameraEventDecoder(listener: self)
        thermalControl = ThermalControlCore(store: deviceController.device.peripheralStore, backend: self)
        loadPresets()
        if isPersisted {
            thermalControl.publish()
        }
    }

    /// Sets thermal control mode
    ///
    /// - Parameter mode: the new thermal control mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: ThermalControlMode) -> Bool {
        presetStore?.write(key: SettingKey.modeKey, value: mode).commit()
        if connected {
            return sendModeCommand(mode)
        } else {
            thermalControl.update(mode: mode).notifyUpdated()
            return false
        }
    }

    /// Set emissivity
    ///
    /// - Parameter emissivity: emissivity value
    func set(emissivity: Double) -> Bool {
        presetStore?.write(key: SettingKey.emissivitykey, value: emissivity).commit()
        if connected {
            return sendEmissivityCommand(Float(emissivity))
        } else {
            thermalControl.update(emissivity: emissivity).notifyUpdated()
            return false
        }
    }

    /// Sets thermal camera calibration mode.
    ///
    /// - Parameter calibrationMode: the new calibration mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(calibrationMode: ThermalCalibrationMode) -> Bool {
        presetStore?.write(key: SettingKey.calibrationModeKey, value: calibrationMode).commit()
        if connected {
            return sendCalibrationModeCommand(calibrationMode)
        } else {
            thermalControl.update(mode: calibrationMode).notifyUpdated()
            return false
        }
    }

    /// Triggers a calibration of the thermal camera.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func calibrate() -> Bool {
        return false
    }

    /// Abort calibration of the thermal camera.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func abortCalibration() -> Bool {
       return false
    }

    /// Confirm to the drone that the user action required by the calibration procedure is done.
    ///
    /// - Returns: true if the command has been sent, false otherwise
    func confirmUserAction() -> Bool {
        return false
    }

    /// Set current palette configuration.
    ///
    /// - Parameter palette: palette configuration
    /// - Returns: true if the command has been sent, false otherwise
    func set(palette: ThermalPalette) -> Bool {
        // save palette in presetStore
        presetStore?.write(key: SettingKey.paletteKey, value: palette).commit()

        if !connected {
            thermalControl.update(palette: palette)
            return false
        }

        var colorSent = false
        if palette.colors != currentColors {
            currentColors = palette.colors
            sendPaletteColorCommands(colors: palette.colors)
            colorSent = true
        }

        let paletteSent = sendPaletteSettingsCommand(palette: palette)
        return colorSent || paletteSent
    }

    /// Set background temperature.
    ///
    /// - Parameter backgroundTemperature: background temperature
    func set(backgroundTemperature: Double) -> Bool {
        presetStore?.write(key: SettingKey.backgroundTemperatureKey, value: backgroundTemperature).commit()
        if connected {
            return sendBackgroundTemperatureCommand(backgroundTemperature: Float(backgroundTemperature))
        } else {
            thermalControl.update(backgroundTemperature: backgroundTemperature).notifyUpdated()
            return false
        }
    }

    func set(powerSavingMode: ThermalPowerSavingMode) -> Bool {
        presetStore?.write(key: SettingKey.powerSavingModeKey, value: powerSavingMode).commit()
        if connected {
            return sendPowerSavingModeCommand(powerSavingMode)
        } else {
            thermalControl.update(powerSavingMode: powerSavingMode).notifyUpdated()
            return false
        }
    }

    /// Set rendering
    ///
    /// - Parameter rendering: rendering configuration
    func set(rendering: ThermalRendering) -> Bool {
        presetStore?.write(key: SettingKey.renderingKey, value: rendering).commit()
        if connected {
            switch rendering.mode {
            case .visible:
                return sendRenderingCommand(mode: .visible, blendingRate: rendering.blendingRate)
            case .thermal:
                return sendRenderingCommand(mode: .thermal, blendingRate: rendering.blendingRate)
            case .blended:
                return sendRenderingCommand(mode: .blended, blendingRate: rendering.blendingRate)
            case .monochrome:
                return sendRenderingCommand(mode: .monochrome, blendingRate: rendering.blendingRate)
            }
        } else {
            thermalControl.update(rendering: rendering).notifyUpdated()
            return false
        }
    }

    /// Set range
    ///
    /// - Parameter range: range
    func set(range: ThermalSensitivityRange) -> Bool {
        presetStore?.write(key: SettingKey.sensitivityRangeKey, value: range).commit()
        if connected {
            switch range {
            case .high:
                return sendSensitivityCommand(range: .high)
            case .low:
                return sendSensitivityCommand(range: .low)
            }
        } else {
            thermalControl.update(range: range).notifyUpdated()
            return false
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore?.clear()
        thermalControl.unpublish()
        super.willForget()
    }

    /// Drone is about to be connect
    override func willConnect() {
        super.willConnect()
        // remove settings stored while connecting. We will get new one on the next connection.
        droneSettings.removeAll()
        currentPaletteSettings = nil
        currentColors = nil
        paletteParts = nil
    }

    /// Drone is connected
    override func didConnect() {
        storeNewPresets()
        applyPresets()
        if thermalControl.modeSetting.supportedModes.isEmpty {
            thermalControl.unpublish()
        } else {
            thermalControl.publish()
        }
        super.didConnect()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        super.didDisconnect()
        expectingColor = false
        expectingPalette = false

        // clear all non saved values
        thermalControl.cancelSettingsRollback().update(mode: .disabled)

        if isPersisted {
            thermalControl.notifyUpdated()
        } else {
            thermalControl.unpublish()
        }
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: ThermalControllerBase.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            for setting in Setting.allCases {
                switch setting {
                case .mode:
                    if let supportedModesValues: StorableArray<ThermalControlMode> = deviceStore.read(key: setting.key),
                       let mode: ThermalControlMode = presetStore.read(key: setting.key) {
                        let supportedModes = Set(supportedModesValues.storableValue)
                        if supportedModes.contains(mode) {
                            thermalControl.update(supportedModes: supportedModes).update(mode: mode)
                        }
                    }
                case .sensitivityRange:
                    if let range: ThermalSensitivityRange = presetStore.read(key: setting.key) {
                        thermalControl.update(range: range)
                    }
                case .calibrationMode:
                    if let calibrationMode: ThermalCalibrationMode = presetStore.read(key: setting.key) {
                        thermalControl.update(mode: calibrationMode)
                    }
                case .palette:
                    if let palette: ThermalPalette = presetStore.read(key: setting.key) {
                        thermalControl.update(palette: palette)
                    }
                case .colors:
                    break
                case .backgroundTemperature:
                    if let backgroundTemperature: Double = presetStore.read(key: setting.key) {
                        thermalControl.update(backgroundTemperature: backgroundTemperature)
                    }
                case .rendering:
                    if let rendering: ThermalRendering = presetStore.read(key: setting.key) {
                        thermalControl.update(rendering: rendering)
                    }
                case .emissivity:
                    if let emissivity: Double = presetStore.read(key: setting.key) {
                        thermalControl.update(emissivity: emissivity)
                    }
                case .powerSavingMode:
                    if let powerSavingMode: ThermalPowerSavingMode = presetStore.read(key: setting.key) {
                        thermalControl.update(powerSavingMode: powerSavingMode)
                    }
                }
                thermalControl.notifyUpdated()
            }
        }
    }

    /// Called when the drone is connected, save all received settings ranges
    private func storeNewPresets() {
        // nothing to do yet
    }

    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .mode(let mode):
                if let preset: ThermalControlMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendModeCommand(preset)
                    }
                    thermalControl.update(mode: preset)
                } else {
                    thermalControl.update(mode: mode)
                }
            case .sensitivityRange(let sensitivityRange):
                if let preset: ThermalSensitivityRange = presetStore?.read(key: setting.key) {
                    if preset != sensitivityRange {
                        _ = set(range: preset)
                    }
                    thermalControl.update(range: preset)
                } else {
                    thermalControl.update(range: sensitivityRange)
                }
            case .calibrationMode(let mode):
                if let preset: ThermalCalibrationMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendCalibrationModeCommand(preset)
                    }
                    thermalControl.update(mode: preset)
                } else {
                    thermalControl.update(mode: mode)
                }
            case .palette(let palette):
                if let preset: ThermalPalette = presetStore?.read(key: setting.key) {
                    if preset != palette {
                        _ = sendPaletteSettingsCommand(palette: preset)
                    }
                    if preset.colors != palette.colors {
                        sendPaletteColorCommands(colors: preset.colors)
                    }
                    thermalControl.update(palette: preset)

                } else {
                    thermalControl.update(palette: palette)
                }

            case .colors:
                break
            case .backgroundTemperature(let backgroundTemperature):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != backgroundTemperature {
                        _ = sendBackgroundTemperatureCommand(backgroundTemperature: Float(preset))
                    }
                    thermalControl.update(backgroundTemperature: preset)
                } else {
                    thermalControl.update(backgroundTemperature: backgroundTemperature)
                }
            case .rendering(let rendering):
                if let preset: ThermalRendering = presetStore?.read(key: setting.key) {
                    if preset != rendering {
                        _ = set(rendering: ThermalRendering(mode: preset.mode, blendingRate: preset.blendingRate))
                    }
                    thermalControl.update(rendering: preset)
                } else {
                    thermalControl.update(rendering: rendering)
                }
            case .emissivity(let emissivity):
                if let preset: Double = presetStore?.read(key: setting.key) {
                    if preset != emissivity {
                        _ = sendEmissivityCommand(Float(preset))
                    }
                    thermalControl.update(emissivity: preset)
                } else {
                    thermalControl.update(emissivity: emissivity)
                }

            case .powerSavingMode(let powerSavingMode):
                if let preset: ThermalPowerSavingMode = presetStore?.read(key: setting.key) {
                    if preset != powerSavingMode {
                        _ = sendPowerSavingModeCommand(preset)
                    }
                    thermalControl.update(powerSavingMode: preset)
                } else {
                    thermalControl.update(powerSavingMode: powerSavingMode)
                }
            }
        }
        thermalControl.notifyUpdated()
    }

    /// Called when a command that notify a setting change has been received
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        if connected {
            switch setting {
            case .mode(let mode):
                thermalControl.update(mode: mode).notifyUpdated()
            case .sensitivityRange(let sensitivityRange):
                thermalControl.update(range: sensitivityRange).notifyUpdated()
            case .calibrationMode(let mode):
                thermalControl.update(mode: mode).notifyUpdated()
            case .palette(let palette):
                expectingPalette = false
                thermalControl.update(palette: palette, updated: !expectingColor).notifyUpdated()
            case .colors(let colors):
                expectingColor = false
                thermalControl.update(colors: colors, updated: !expectingPalette).notifyUpdated()
            case .backgroundTemperature(let backgroundTemperature):
                thermalControl.update(backgroundTemperature: backgroundTemperature).notifyUpdated()
            case .rendering(let rendering):
                thermalControl.update(rendering: rendering).notifyUpdated()
            case .emissivity(let emissivity):
                thermalControl.update(emissivity: emissivity).notifyUpdated()
            case .powerSavingMode(let powerSavingMode):
                thermalControl.update(powerSavingMode: powerSavingMode).notifyUpdated()
            }
        }
    }

    /// Process stored capabilities changes
    ///
    /// Update thermal control and device store. Caller must call `ThermalControl.notifyUpdated()` to notify change.
    ///
    /// - Parameter capabilities: changed capabilities
    func capabilitiesDidChange(_ capabilities: Capabilities) {
        switch capabilities {
        case .mode(let modes):
            deviceStore?.write(key: capabilities.key, value: StorableArray(Array(modes)))
            thermalControl.update(supportedModes: modes)
        }
        deviceStore?.commit()
    }

    /// A command has been received
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureThermalUid {
            ArsdkFeatureThermal.decode(command, callback: self)
        }

        cameraDecoder.decode(command)
    }

    /// Send mode command.
    ///
    /// - Parameter mode: requested mode.
    /// - Returns: true if the command has been sent
    func sendModeCommand(_ mode: ThermalControlMode) -> Bool {
        switch mode {
        case .standard:
            return sendCommand(ArsdkFeatureThermal.setModeEncoder(mode: .standard))
        case .disabled:
            return sendCommand(ArsdkFeatureThermal.setModeEncoder(mode: .disabled))
        case .blended:
            return sendCommand(ArsdkFeatureThermal.setModeEncoder(mode: .blended))
        }
    }

    /// Send emissivity command.
    ///
    /// - Parameter emissivity: requested emissivity.
    func sendEmissivityCommand(_ emissivity: Float) -> Bool {
        return sendCommand(ArsdkFeatureThermal.setEmissivityEncoder(emissivity: emissivity))
    }

    /// Send calibration mode command.
    ///
    /// - Parameter mode: requested mode.
    /// - Returns: true if the command has been sent
    func sendCalibrationModeCommand(_ mode: ThermalCalibrationMode) -> Bool {
        switch mode {
        case .automatic:
            return sendCommand(ArsdkFeatureThermal.setShutterModeEncoder(trigger: .auto))
        case .manual:
            return sendCommand(ArsdkFeatureThermal.setShutterModeEncoder(trigger: .manual))
        }
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

    /// Send palette colors.
    ///
    /// - Parameter colors: colors to send
    func sendPaletteColorCommands(colors: [ThermalColor]) {
        expectingColor = true
        if colors.count == 0 {
            // empty color list
            let listFlagsBitField: UInt = Bitfield<ArsdkFeatureGenericListFlags>.of(.empty)
            _ = sendCommand(ArsdkFeatureThermal.setPalettePartEncoder(red: 0, green: 0, blue: 0, index: 0,
                                                                  listFlagsBitField: listFlagsBitField))
            return
        }
        var index = 0
        for color in colors {
            var listFlagsBitField: UInt = 0
            if index == 0 {
                // list flag for first element
                listFlagsBitField = Bitfield<ArsdkFeatureGenericListFlags>.of(.first)
            }
            if index == colors.count - 1 {
                // list flag for last element
                listFlagsBitField |= Bitfield<ArsdkFeatureGenericListFlags>.of(.last)
            }
            _ = sendCommand(ArsdkFeatureThermal.setPalettePartEncoder(red: Float(color.red),
                                                                  green: Float(color.green),
                                                                  blue: Float(color.blue),
                                                                  index: Float(color.position),
                                                                  listFlagsBitField: listFlagsBitField))
            index += 1
        }
    }

    /// Send palette settings.
    ///
    /// - Parameters:
    ///    - palette: the new palette to send
    /// - Returns: tells whether the palette command has been sent
    func sendPaletteSettingsCommand(palette: ThermalPalette) -> Bool {
        switch palette.type {
        case .absolute(let lowestTemperature, let highestTemperature, let outsideColorization):
            return sendPaletteSettingsCommand(mode: .absolute,
                                       lowestTemp: lowestTemperature,
                                       highestTemp: highestTemperature,
                                       outsideColorization: outsideColorization)
        case .relative(let lowestTemperature, let highestTemperature, let locked):
            return sendPaletteSettingsCommand(mode: .relative,
                                           lowestTemp: lowestTemperature,
                                           highestTemp: highestTemperature,
                                           locked: locked)
        case .spot(let type, let threshold):
            return sendPaletteSettingsCommand(mode: .spot, spotType: type,
                                           spotThreshold: threshold)
        }

    }

    /// Send palette settings.
    ///
    /// - Parameters:
    ///    - mode: palette mode
    ///    - lowestTemp: temperature associated to the lower boundary of the palette, in Kelvin,
    ///                  used only when palette mode is 'absolute' or when mode is 'relative' and 'locked'
    ///    - highestTemp: temperature associated to the higher boundary of the palette, in Kelvin,
    ///                  used only when palette mode is 'absolute' or when mode is 'relative' and 'locked'
    ///    - outsideColorization: colorization mode outside palette bounds when palette mode is 'absolute'
    ///    - locked: when palette mode is 'relative', 'true' to lock the palette, 'false' to unlock
    ///    - spotType: temperature type to highlight, when palette mode is 'spot'
    ///    - spotThreshold: threshold palette index for highlighting, from 0 to 1, when palette mode is 'spot'
    /// - Returns: tells whether the palette command has been sent
    func sendPaletteSettingsCommand(mode: ArsdkFeatureThermalPaletteMode,
                                    lowestTemp: Double = 0, highestTemp: Double = 0,
                                    outsideColorization: ThermalColorizationMode = .extended,
                                    locked: Bool = false,
                                    spotType: ThermalSpotType = .hot, spotThreshold: Double = 0) -> Bool {
        // outside colorization mode for absolute palette
        let arsdkOutsideColorization = outsideColorization.arsdkValue!

        // locked or unlocked mode for relative palette
        let relativeRangeMode: ArsdkFeatureThermalRelativeRangeMode = locked ? .locked : .unlocked
        // temperature type to highlight for spot palette
        let arsdkSpotType = spotType.arsdkValue!

        let paletteSettings = ArsdkThermalPaletteSettings(mode: mode,
                                                          lowestTemp: Float(lowestTemp),
                                                          highestTemp: Float(highestTemp),
                                                          outsideColorization: arsdkOutsideColorization,
                                                          relativeRangeMode: relativeRangeMode,
                                                          spotType: arsdkSpotType,
                                                          spotThreshold: Float(spotThreshold))
        if paletteSettings != currentPaletteSettings {
            currentPaletteSettings = paletteSettings
            expectingPalette = true
            // send command
            return sendCommand(ArsdkFeatureThermal.setPaletteSettingsEncoder(mode: mode,
                                                                      lowestTemp: Float(lowestTemp),
                                                                      highestTemp: Float(highestTemp),
                                                                      outsideColorization: arsdkOutsideColorization,
                                                                      relativeRange: relativeRangeMode,
                                                                      spotType: arsdkSpotType,
                                                                      spotThreshold: Float(spotThreshold)))
        }
        return false
    }

    /// Send background temperature.
    ///
    /// - Parameter backgroundTemperature: background temperature to send
    /// - Returns: true if the command has been sent
    func sendBackgroundTemperatureCommand(backgroundTemperature: Float) -> Bool {
        return sendCommand(ArsdkFeatureThermal.setBackgroundTemperatureEncoder(
            backgroundTemperature: backgroundTemperature))
    }

    /// Send rendering
    ///
    /// - Parameters:
    ///    - mode: mode
    ///    - blendingRate: blending rate
    /// - Returns: true if the command has been sent
    func sendRenderingCommand(mode: ArsdkFeatureThermalRenderingMode, blendingRate: Double) -> Bool {
        return sendCommand(ArsdkFeatureThermal.setRenderingEncoder(mode: mode, blendingRate: Float(blendingRate)))
    }

    /// Send sensitivity
    ///
    /// - Parameter range: sensitivity range
    /// - Returns: true if the command has been sent
    func sendSensitivityCommand(range: ArsdkFeatureThermalRange) -> Bool {
        return sendCommand(ArsdkFeatureThermal.setSensitivityEncoder(range: range))
    }
}

/// Thermal feature decode callback implementation
extension ThermalControllerBase: ArsdkFeatureThermalCallback {

    func onMode(mode: ArsdkFeatureThermalMode) {
        switch mode {
        case .standard:
            settingDidChange(.mode(.standard))
        case .disabled:
            settingDidChange(.mode(.disabled))
        case .blended:
            settingDidChange(.mode(.blended))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change the thermal control modes
            ULog.w(.tag, "Unknown thermal control mode, skipping this event.")
        }
    }

    func onCapabilities(modesBitField: UInt) {
        var availableMode: Set<ThermalControlMode> = []
        if ArsdkFeatureThermalModeBitField.isSet(.disabled, inBitField: modesBitField) {
            availableMode.insert(.disabled)
        }
        if ArsdkFeatureThermalModeBitField.isSet(.standard, inBitField: modesBitField) {
            availableMode.insert(.standard)
        }
        if ArsdkFeatureThermalModeBitField.isSet(.blended, inBitField: modesBitField) {
            availableMode.insert(.blended)
        }
        capabilitiesDidChange(.mode(availableMode))
        thermalControl.notifyUpdated()
    }

    func onBackgroundTemperature(backgroundTemperature: Float) {
        settingDidChange(.backgroundTemperature(Double(backgroundTemperature)))
    }

    func onEmissivity(emissivity: Float) {
        settingDidChange(.emissivity(Double(emissivity)))
    }

    func onRendering(mode: ArsdkFeatureThermalRenderingMode, blendingRate: Float) {
        switch mode {
        case .blended:
            settingDidChange(.rendering(ThermalRendering(mode: .blended, blendingRate: Double(blendingRate))))
        case .monochrome:
            settingDidChange(.rendering(ThermalRendering(mode: .monochrome, blendingRate: Double(blendingRate))))
        case .thermal:
            settingDidChange(.rendering(ThermalRendering(mode: .thermal, blendingRate: Double(blendingRate))))
        case .visible:
            settingDidChange(.rendering(ThermalRendering(mode: .visible, blendingRate: Double(blendingRate))))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change the palette
            ULog.w(.tag, "Unknown thermal rendering mode, skipping this event.")
        }

    }

    func onPalettePart(red: Float, green: Float, blue: Float, index: Float, listFlagsBitField: UInt) {
        if paletteParts == nil {
            paletteParts = []
        }
        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            paletteParts = []
            currentColors = [ThermalColor]()
            settingDidChange(.colors(currentColors!))
        } else {
            let color = ThermalColor(Double(red), Double(green), Double(blue), Double(index))
            if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                currentColors?.removeAll(where: { $0 == color })
                settingDidChange(.colors([]))
            } else {
                if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                    paletteParts = []
                }
                paletteParts?.append(color)
                if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                    currentColors = paletteParts
                    paletteParts = nil
                    if let currentColors = currentColors {
                        settingDidChange(.colors(currentColors))
                    }
                }
            }
        }
    }

    func onPaletteSettings(mode: ArsdkFeatureThermalPaletteMode, lowestTemp: Float, highestTemp: Float,
                           outsideColorization: ArsdkFeatureThermalColorizationMode,
                           relativeRange: ArsdkFeatureThermalRelativeRangeMode,
                           spotType: ArsdkFeatureThermalSpotType, spotThreshold: Float) {
        currentPaletteSettings = ArsdkThermalPaletteSettings(mode: mode,
                                                             lowestTemp: lowestTemp,
                                                             highestTemp: highestTemp,
                                                             outsideColorization: outsideColorization,
                                                             relativeRangeMode: relativeRange,
                                                             spotType: spotType,
                                                             spotThreshold: spotThreshold)
        // Check palette type and create the new palette.
        switch mode {
        case .absolute:
            guard let thermalOutsideColorization = ThermalColorizationMode(fromArsdk: outsideColorization)
                else { return }
            let palette = ThermalPalette(colors: currentColors ?? [ThermalColor](),
                                         type: ThermalPaletteType.absolute(
                                                 lowestTemperature: Double(lowestTemp),
                                                 highestTemperature: Double(highestTemp),
                                                 outsideColorization: thermalOutsideColorization))
            settingDidChange(.palette(palette))
        case .relative:
            let palette = ThermalPalette(colors: currentColors ?? [ThermalColor](),
                                         type: ThermalPaletteType.relative(
                                                 lowestTemperature: Double(lowestTemp),
                                                 highestTemperature: Double(highestTemp),
                                                 locked: relativeRange == .locked))
            settingDidChange(.palette(palette))
        case .spot:
            guard let thermalSpotType = ThermalSpotType(fromArsdk: spotType) else { return }
            let palette = ThermalPalette(colors: currentColors ?? [ThermalColor](),
                                         type: ThermalPaletteType.spot(
                                            type: thermalSpotType, threshold: Double(spotThreshold)))
            settingDidChange(.palette(palette))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change the palette
            ULog.w(.tag, "Unknown thermal palette mode, skipping this event.")
        }

    }

    func onSensitivity(currentRange: ArsdkFeatureThermalRange) {
        switch currentRange {
        case .high:
            settingDidChange(.sensitivityRange(.high))
        case .low:
            settingDidChange(.sensitivityRange(.low))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change the range of sensitivity
            ULog.w(.tag, "Unknown thermal range, skipping this event.")
        }
    }

    func onShutterMode(currentTrigger: ArsdkFeatureThermalShutterTrigger) {
        switch currentTrigger {
        case .auto:
            settingDidChange(.calibrationMode(.automatic))
        case .manual:
            settingDidChange(.calibrationMode(.manual))
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change the thermal calibration modes
            ULog.w(.tag, "Unknown thermal shutter mode, skipping this event.")
        }
    }
}


extension ThermalControllerBase: ArsdkCameraEventDecoderListener {
    func onState(_ state: Arsdk_Camera_Event.State) {
        if state.hasThermalPalette || state.hasThermalRendering {
            deviceStore?.clear()
            thermalControl.unpublish()
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

/// Structure allowing to store palette settings sent to drone or received from drone.
private struct ArsdkThermalPaletteSettings: Equatable {

    /// Palette mode.
    let mode: ArsdkFeatureThermalPaletteMode

    /// Lowest temperature, in Kelvin.
    let lowestTemp: Float

    /// Highest temperature, in Kelvin.
    let highestTemp: Float

    /// Outside colorization mode for absolute palette.
    let outsideColorization: ArsdkFeatureThermalColorizationMode

    /// Locked or unlocked mode for relative palette.
    let relativeRangeMode: ArsdkFeatureThermalRelativeRangeMode

    /// Temperature type to highlight for spot palette.
    let spotType: ArsdkFeatureThermalSpotType

    /// Threshold for spot palette, from 0 to 1.
    let spotThreshold: Float
}

extension ThermalRendering: StorableType {
    /// Store keys
    private enum Key {
        static let mode = "mode"
        static let blendingRate = "blendingRate"
    }

    /// Constructor from store data
    ///
    /// - Parameter content: store data
    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
           let mode = ThermalRenderingMode(content[Key.mode]),
           let blendingRate = Double(content[Key.blendingRate]) {
            self.init(mode: mode, blendingRate: blendingRate)
        } else {
            return nil
        }
    }

    /// Convert data to storable
    ///
    /// - Returns: Storable containing data
    func asStorable() -> StorableProtocol {
        return StorableDict<String, AnyStorable>([
            Key.mode: AnyStorable(mode),
            Key.blendingRate: AnyStorable(blendingRate)
        ])
    }
}

/// Extension to make ThermalPalette storable
extension ThermalPalette: StorableType {

    /// Store keys
    private enum Key {
        static let mode = "mode"
        static let lowestTemperature = "lowestTemperature"
        static let highestTemperature = "highestTemperature"
        static let locked = "locked"
        static let outsideColorization = "outsideColorization"
        static let spotType = "spotType"
        static let spotThreshold = "spotThreshold"
        static let colors = "colors"
    }

    /// Constructor from store data
    ///
    /// - Parameter content: store data
    init?(from content: AnyObject?) {
        if let content = StorableDict<String, AnyStorable>(from: content),
           let mode = ThermalPaletteMode(content[Key.mode]),
           let colors = StorableArray<ThermalColor>(content[Key.colors]) {
            var storableColors = [ThermalColor]()
            for color in colors.storableValue {
                storableColors.append(color)
            }

            switch mode {
            case .absolute:
                if let lowestTemperature = Double(content[Key.lowestTemperature]),
                   let highestTemperature = Double(content[Key.highestTemperature]),
                   let outsideColorization = ThermalColorizationMode(content[Key.outsideColorization]) {
                    self.init(colors: storableColors, type: ThermalPaletteType.absolute(
                        lowestTemperature: lowestTemperature,
                        highestTemperature: highestTemperature,
                        outsideColorization: outsideColorization))
                } else {
                    return nil
                }
            case .relative:
                if let lowestTemperature = Double(content[Key.lowestTemperature]),
                   let highestTemperature = Double(content[Key.highestTemperature]),
                   let locked = Bool(content[Key.locked]) {
                    self.init(colors: storableColors, type: ThermalPaletteType.relative(
                        lowestTemperature: lowestTemperature,
                        highestTemperature: highestTemperature, locked: locked))
                } else {
                    return nil
                }
            case .spot:
                if let spotType = ThermalSpotType(content[Key.spotType]),
                   let spotThreshold = Double(content[Key.spotThreshold]) {
                    self.init(colors: storableColors, type: ThermalPaletteType.spot(type: spotType,
                                                                                    threshold: spotThreshold))
                } else {
                    return nil
                }
            }
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
        switch type {
        case .absolute(let lowestTemperature, let highestTemperature, let outsideColorization):
            return StorableDict<String, AnyStorable>([
                Key.mode: AnyStorable(ThermalPaletteMode.absolute),
                Key.lowestTemperature: AnyStorable(lowestTemperature),
                Key.highestTemperature: AnyStorable(highestTemperature),
                Key.outsideColorization: AnyStorable(outsideColorization),
                Key.colors: AnyStorable(StorableArray<ThermalColor>(colorsStorable))
            ])
        case .relative(let lowestTemperature, let highestTemperature, let locked):
            return StorableDict<String, AnyStorable>([
                Key.mode: AnyStorable(ThermalPaletteMode.relative),
                Key.lowestTemperature: AnyStorable(lowestTemperature),
                Key.highestTemperature: AnyStorable(highestTemperature),
                Key.locked: AnyStorable(locked),
                Key.colors: AnyStorable(StorableArray<ThermalColor>(colorsStorable))
            ])
        case .spot(let type, let threshold):
            return StorableDict<String, AnyStorable>([
                Key.mode: AnyStorable(ThermalPaletteMode.spot),
                Key.spotType: AnyStorable(type),
                Key.spotThreshold: AnyStorable(threshold),
                Key.colors: AnyStorable(StorableArray<ThermalColor>(colorsStorable))
            ])
        }
    }
}

/// Extension to make ThermalPaletteMode storable
private enum ThermalPaletteMode: Int, CustomStringConvertible, CaseIterable, StorableEnum {
    /// Absolute palette range.
    case absolute
    /// Relative palette range.
    case relative
    /// Palette above or under relative threshold.
    case spot

    /// Debug description.
    public var description: String {
        switch self {
        case .absolute: return "absolute"
        case .relative: return "relative"
        case .spot: return "spot"
        }
    }

    static var storableMapper = Mapper<ThermalPaletteMode, String>([
        .absolute: "absolute",
        .relative: "relative",
        .spot: "spot"])
}

/// Extension to make ThermalSpotType storable
extension ThermalSpotType: StorableEnum {
    static var storableMapper = Mapper<ThermalSpotType, String>([
        .cold: "cold",
        .hot: "hot"])
}

/// Extension to make ThermalControlMode storable
extension ThermalControlMode: StorableEnum {
    static var storableMapper = Mapper<ThermalControlMode, String>([
        .standard: "standard",
        .disabled: "disabled",
        .blended: "blended"])
}

/// Extension to make Thermal sensitivity range storable
extension ThermalSensitivityRange: StorableEnum {
    static var storableMapper = Mapper<ThermalSensitivityRange, String>([
        .high: "high",
        .low: "low"])
}

/// Extension to make Thermal colorization mode storable
extension ThermalColorizationMode: StorableEnum {
    static var storableMapper = Mapper<ThermalColorizationMode, String>([
        .extended: "extended",
        .limited: "limited"])
}

/// Extension to make ThermalRenderingMode storable
extension ThermalRenderingMode: StorableEnum {
    static var storableMapper = Mapper<ThermalRenderingMode, String>([
        .blended: "blended",
        .monochrome: "monochrome",
        .thermal: "thermal",
        .visible: "visible"])
}

/// Extension to make ThermalCalibrationMode storable
extension ThermalCalibrationMode: StorableEnum {
    static var storableMapper = Mapper<ThermalCalibrationMode, String>([
        .automatic: "automatic",
        .manual: "manual"])
}

/// Extension that adds conversion from/to arsdk enum.
extension ThermalSpotType: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<ThermalSpotType, ArsdkFeatureThermalSpotType>([
        .cold: .cold,
        .hot: .hot
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension ThermalControlMode: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<ThermalControlMode, ArsdkFeatureThermalMode>([
        .disabled: .disabled,
        .standard: .standard,
        .blended: .blended
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension ThermalColorizationMode: ArsdkMappableEnum {
    static var arsdkMapper = Mapper<ThermalColorizationMode, ArsdkFeatureThermalColorizationMode>([
        .limited: .limited,
        .extended: .extended
    ])
}
