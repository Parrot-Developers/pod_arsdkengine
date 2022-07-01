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

/// Cellular supported capabilities
public enum CellularSupportedCapabilities: String, CaseIterable {

    /// Cellular 4G is supported
    case support4g

    /// Debug description.
    public var description: String {
        switch self {
        case .support4g:         return "support4g"
        }
    }
}

/// Base controller for cellular peripheral
class CellularController: DeviceComponentController, CellularBackend {
    /// Main modem identifier
    private let MODEM_ID_MAIN: UInt = 0

    /// Cellular component
    private var cellular: CellularCore!

    /// `true` if cellular is supported by the drone.
    private var isSupported = false

    /// component settings key
    private static let settingKey = "CellularController"

    /// Store device specific values
    public let deviceStore: SettingsStore

    /// Preset store for this component
    private var presetStore: SettingsStore?

    /// Store APN configuration values
    private var apnConfigurationPresets: ApnConfigurationPresets!

    /// All data that can be stored
    enum PersistedDataKey: String, StoreKey {
        case imei = "imei"
    }

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case mode = "mode"
        case isRoamingAllowed = "isRoamingAllowed"
        case apnConfiguration = "apnConfiguration"
        case networkMode = "networkMode"
    }

    /// Stored settings
    enum Setting: Hashable {
        case mode(CellularMode)
        case isRoamingAllowed(Bool)
        case apnConfiguration(Bool, String, String, String)
        case networkMode(CellularNetworkMode)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .mode: return .mode
            case .isRoamingAllowed: return .isRoamingAllowed
            case .apnConfiguration: return .apnConfiguration
            case .networkMode: return .networkMode
            }
        }
        /// All values to allow enumerating settings
        static let allCases: Set<Setting> = [.mode(.disabled), .isRoamingAllowed(false),
                                             .apnConfiguration(false, "", "", ""), .networkMode(.auto)]

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }

        static func == (lhs: Setting, rhs: Setting) -> Bool {
            return lhs.key == rhs.key
        }
    }

    /// Setting values as received from the drone
    private var droneSettings = Set<Setting>()

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        deviceStore = deviceController.deviceStore.getSettingsStore(key: CellularController.settingKey)
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            presetStore = nil
        } else {
            presetStore = deviceController.presetStore.getSettingsStore(key: CellularController.settingKey)
        }

        super.init(deviceController: deviceController)
        cellular = CellularCore(store: deviceController.device.peripheralStore, backend: self)
        apnConfigurationPresets = ApnConfigurationPresets(apnSetting: cellular.apnConfigurationSetting)

        var publish = false
        // load persisted data
        if !deviceStore.new {
            loadPersistedData()
            publish = true
        }
        // load settings
        if let presetStore = presetStore, !presetStore.new {
            loadPresets()
            publish = true
        }
        if publish {
            cellular.publish()
        }
    }

    /// Load saved values
    private func loadPersistedData() {
        if let imei: String = deviceStore.read(key: PersistedDataKey.imei) {
            cellular.update(imei: imei)
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore {
            for setting in Setting.allCases {
                switch setting {
                case .mode:
                    if let mode: CellularMode = presetStore.read(key: setting.key) {
                        cellular.update(mode: mode)
                    }
                case .apnConfiguration:
                    if let apnConfigurationPresetsData: ApnConfigurationPresets.Data =
                        presetStore.read(key: setting.key) {
                        apnConfigurationPresets.load(data: apnConfigurationPresetsData)
                        cellular.update(isApnManual: apnConfigurationPresets.isManual)
                            .update(apnUrl: apnConfigurationPresets.url)
                            .update(apnUsername: apnConfigurationPresets.username)
                            .update(apnPassword: apnConfigurationPresets.password)
                    }
                case .isRoamingAllowed:
                    if let isRoamingAllowed: Bool = presetStore.read(key: setting.key) {
                        cellular.update(isRoamingAllowed: isRoamingAllowed)
                    }
                case .networkMode:
                    if let networkMode: CellularNetworkMode = presetStore.read(key: setting.key) {
                        cellular.update(networkMode: networkMode)
                    }
                }
                cellular.notifyUpdated()
            }
        }
    }

    /// Drone is connected
    override func didConnect() {
        applyPresets()
        if isSupported {
            cellular.publish()
        } else {
            cellular.unpublish()
        }
    }

    /// Drone is disconnected
    override func didDisconnect() {
        if cellular.resetState == .ongoing {
            cellular.update(resetState: .success).notifyUpdated()
        }
        // clear all non saved values
        cellular.cancelSettingsRollback()
            .update(simStatus: .unknown)
            .update(simIccid: "")
            .update(simImsi: "")
            .update(registrationStatus: .notRegistered)
            .update(operator: "")
            .update(technology: .edge)
            .update(modemStatus: .off)
            .update(networkStatus: .deactivated)
            .update(isPinCodeRequested: false)
            .update(isPinCodeInvalid: false)
            .update(pinRemainingTries: 0)
            .update(resetState: .none)

        isSupported = false

        // unpublish if offline settings are disabled
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            cellular.unpublish()
        } else {
            cellular.notifyUpdated()
        }
    }

    /// Drone is about to be forgotten
    override func willForget() {
        deviceStore.clear()
        cellular.unpublish()
        super.willForget()
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: CellularController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Apply presets
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .mode(let mode):
                if let preset: CellularMode = presetStore?.read(key: setting.key) {
                    if preset != mode {
                        _ = sendModeCommand(preset)
                    }
                    cellular.update(mode: preset)
                } else {
                    cellular.update(mode: mode)
                }
            case .apnConfiguration(let isManual, let url, let username, let password):
                if let data: ApnConfigurationPresets.Data = presetStore?.read(key: setting.key) {
                    apnConfigurationPresets.load(data: data)
                    let presetIsManual = apnConfigurationPresets.isManual
                    let presetUrl = apnConfigurationPresets.url
                    let presetUsername = apnConfigurationPresets.username
                    let presetPassword = apnConfigurationPresets.password

                    if presetIsManual != isManual || presetUrl != url ||
                        presetUsername != username || presetPassword != password {
                        _ = sendApnConfigurationCommand(presetIsManual, presetUrl, presetUsername, presetPassword)
                    }
                    cellular.update(isApnManual: presetIsManual)
                        .update(apnUrl: presetUrl)
                        .update(apnUsername: presetUsername)
                        .update(apnPassword: presetPassword)
                } else {
                    cellular.update(isApnManual: isManual)
                        .update(apnUrl: url)
                        .update(apnUsername: username)
                        .update(apnPassword: password)
                }
            case .isRoamingAllowed(let isRoamingAllowed):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset != isRoamingAllowed {
                        _ = sendRoamingAllowedCommand(preset)
                    }
                    cellular.update(isRoamingAllowed: preset)
                } else {
                    cellular.update(isRoamingAllowed: isRoamingAllowed)
                }
            case .networkMode(let networkMode):
                if let preset: CellularNetworkMode = presetStore?.read(key: setting.key) {
                    if preset != networkMode {
                        _ = sendNetworkModeCommand(preset)
                    }
                    cellular.update(networkMode: preset)
                } else {
                    cellular.update(networkMode: networkMode)
                }
            }
            cellular.notifyUpdated()
        }
    }

    /// Called when a command that notifies a setting change has been received
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        if connected {
            switch setting {
            case .mode(let mode):
                cellular.update(mode: mode)
            case .apnConfiguration(let isManual, let url, let username, let password):
                cellular.update(isApnManual: isManual)
                    .update(apnUrl: url)
                    .update(apnUsername: username)
                    .update(apnPassword: password)
            case .isRoamingAllowed(let isRoamingAllowed):
                cellular.update(isRoamingAllowed: isRoamingAllowed)
            case .networkMode(let networkMode):
                cellular.update(networkMode: networkMode)
            }
        }
        cellular.notifyUpdated()
    }

    /// Sets cellular mode
    ///
    /// - Parameter mode: the new cellular mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(mode: CellularMode) -> Bool {
        presetStore?.write(key: SettingKey.mode, value: mode).commit()
        if connected {
            return sendModeCommand(mode)
        } else {
            cellular.update(mode: mode).notifyUpdated()
            return false
        }
    }

    /// Sets roaming allowed
    ///
    /// - Parameter isRoamingAllowed: the new roaming allowed value
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(isRoamingAllowed: Bool) -> Bool {
        presetStore?.write(key: SettingKey.isRoamingAllowed, value: isRoamingAllowed).commit()
        if connected {
            return sendRoamingAllowedCommand(isRoamingAllowed)
        } else {
            cellular.update(isRoamingAllowed: isRoamingAllowed).notifyUpdated()
            return false
        }
    }

    func set(apnConfiguration: (isManual: Bool, url: String, username: String, password: String)) -> Bool {

        let shouldSendCommand = apnConfiguration.isManual != apnConfigurationPresets.isManual
            || apnConfiguration.url != apnConfigurationPresets.url
            || apnConfiguration.username != apnConfigurationPresets.username
            || apnConfiguration.password != apnConfigurationPresets.password
        apnConfigurationPresets.update(isManual: apnConfiguration.isManual,
                                       url: apnConfiguration.url,
                                       username: apnConfiguration.username,
                                       password: apnConfiguration.password)
        presetStore?.write(key: SettingKey.apnConfiguration, value: apnConfigurationPresets.data).commit()
        if connected && shouldSendCommand {
            return sendApnConfigurationCommand(apnConfiguration.isManual, apnConfiguration.url,
                                               apnConfiguration.username, apnConfiguration.password)
        } else {
            cellular.update(isApnManual: apnConfiguration.isManual)
                .update(apnUrl: apnConfiguration.url)
                .update(apnUsername: apnConfiguration.username)
                .update(apnPassword: apnConfiguration.password)
                .notifyUpdated()
            return false
        }
    }

    /// Sets network mode
    ///
    /// - Parameter networkMode: the new network mode
    /// - Returns: true if the command has been sent, false if not connected and the value has been changed immediately
    func set(networkMode: CellularNetworkMode) -> Bool {
        presetStore?.write(key: SettingKey.networkMode, value: networkMode).commit()
        if connected {
            return sendNetworkModeCommand(networkMode)
        } else {
            cellular.update(networkMode: networkMode).notifyUpdated()
            return false
        }
    }

    /// Enter PIN to unlock SIM card
    ///
    /// - Parameter pincode: the PIN code to submit
    /// - Returns: true if the command has been sent, false if not connected
    ///     and the value has been changed immediately
    func enterPinCode(pincode: String) -> Bool {
        if connected {
            return sendPinCodeCommand(pincode)
        }
        return false
    }

    /// Resets cellular settings and reboots the product if it is not flying.
    ///
    /// - Returns: `true` if the command has been sent, `false` otherwise
    func resetSettings() -> Bool {
        if connected {
            sendCommand(ArsdkFeatureCellular.resetConfigEncoder())
            return true
        }
        return false
    }

    /// Send mode command. Subclass must override this function to send the command
    ///
    /// - Parameter mode: requested mode.
    /// - Returns: true if the command has been sent
    func sendModeCommand(_ mode: CellularMode) -> Bool {
        var arsdMode: ArsdkFeatureCellularMode = .disabled
        switch mode {
        case .disabled:
            arsdMode = .disabled
        case .nodata:
            arsdMode = .nodata
        case .data:
            arsdMode = .data
        }
        sendCommand(ArsdkFeatureCellular.setModeEncoder(modemId: MODEM_ID_MAIN, mode: arsdMode))
        return true
    }

    /// Send APN configuration command. Subclass must override this function to send the command
    ///
    /// - Parameters :
    ///  - isManual: requested isManual.
    ///  - url: requested url.
    ///  - username: requested username.
    ///  - password: requested password.
    /// - Returns: true if the command has been sent
    func sendApnConfigurationCommand(_ isManual: Bool, _ url: String,
                                     _ username: String,
                                     _ password: String) -> Bool {
        sendCommand(ArsdkFeatureCellular.setApnEncoder(modemId: MODEM_ID_MAIN, mode: isManual ? 1 : 0,
                                                       url: url, username: username, password: password))
        return true
    }

    /// Send roaming allowed command. Subclass must override this function to send the command
    ///
    /// - Parameter isRoamingAllowed: requested isRoamingAllowed.
    /// - Returns: true if the command has been sent
    func sendRoamingAllowedCommand(_ isRoamingAllowed: Bool) -> Bool {
        sendCommand(ArsdkFeatureCellular.setRoamingAllowedEncoder(modemId: MODEM_ID_MAIN,
                                                                  allowed: isRoamingAllowed ? 1 : 0))
        return true
    }

    /// Send network mode command. Subclass must override this function to send the command
    ///
    /// - Parameter networkMode: requested network mode.
    /// - Returns: true if the command has been sent
    func sendNetworkModeCommand(_ networkMode: CellularNetworkMode) -> Bool {
        var arsdNetworkMode: ArsdkFeatureCellularNetworkMode = .modeAuto
        switch networkMode {
        case .auto:
            arsdNetworkMode = .modeAuto
        case .mode3g:
            arsdNetworkMode = .mode3g
        case .mode4g:
            arsdNetworkMode = .mode4g
        case .mode5g:
            arsdNetworkMode = .mode5g
        }
        sendCommand(ArsdkFeatureCellular.setNetworkModeEncoder(modemId: MODEM_ID_MAIN, networkMode: arsdNetworkMode))
        return true
    }

    /// Send PIN code command. Subclass must override this function to send the command
    ///
    /// - Parameter pincode: new PIN code to unlock the SIM card.
    /// - Returns: true if the command has been sent
    func sendPinCodeCommand(_ pincode: String) -> Bool {
        sendCommand(ArsdkFeatureCellular.setPinCodeEncoder(modemId: MODEM_ID_MAIN, pin: pincode))
        return true
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCellularUid {
            ArsdkFeatureCellular.decode(command, callback: self)
        }
    }
}

/// Cellular decode callback implementation
extension CellularController: ArsdkFeatureCellularCallback {
    func onCapabilities(modemId: UInt, supportedCapabilitiesBitField: UInt) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        if ArsdkFeatureCellularSupportedCapabilitiesBitField.isSet(.capabilities4g,
                                                                   inBitField: supportedCapabilitiesBitField) {
            isSupported = true
        }
    }

    func onMode(modemId: UInt, mode: ArsdkFeatureCellularMode) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        let newMode: CellularMode
        switch mode {
        case .disabled:
            newMode = .disabled
        case .nodata:
            newMode = .nodata
        case .data:
            newMode = .data
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown mode, skipping this cellular mode event.")
            return
        }
        settingDidChange(.mode(newMode))
    }

    func onSimInformation(modemId: UInt, status: ArsdkFeatureCellularSimStatus, iccid: String, imsi: String) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        var newStatus: CellularSimStatus = .unknown
        switch status {
        case .unknown:
            newStatus = .unknown
        case .absent:
            newStatus = .absent
        case .initializing:
            newStatus = .initializing
        case .locked:
            newStatus = .locked
        case .ready:
            newStatus = .ready
            cellular.update(isPinCodeRequested: false).update(isPinCodeInvalid: false)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown status, skipping this cellular SIM Information event.")
            return
        }
        cellular.update(simStatus: newStatus)
            .update(simIccid: iccid)
            .update(simImsi: imsi)
            .notifyUpdated()
    }

    func onRoamingAllowed(modemId: UInt, roamingAllowed: UInt) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        settingDidChange(.isRoamingAllowed(roamingAllowed != 0))
    }

    func onNetworkInformation(modemId: UInt, status: ArsdkFeatureCellularNetworkStatus) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        var newNetworkStatus: CellularNetworkStatus = .deactivated
        switch status {
        case .deactivated:
            newNetworkStatus = .deactivated
        case .activated:
            newNetworkStatus = .activated
        case .denied:
            newNetworkStatus = .denied
        case .error:
            newNetworkStatus = .error
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown status, skipping this cellular Network Information event.")
            return
        }
        cellular.update(networkStatus: newNetworkStatus).notifyUpdated()
    }

    func onNetworkMode(modemId: UInt, networkMode: ArsdkFeatureCellularNetworkMode) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        var newNetworkMode: CellularNetworkMode = .auto
        switch networkMode {
        case .modeAuto:
            newNetworkMode = .auto
        case .mode3g:
            newNetworkMode = .mode3g
        case .mode4g:
            newNetworkMode = .mode4g
        case .mode5g:
            newNetworkMode = .mode5g
        case .modeSdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown network mode, skipping this cellular Network Mode event.")
            return
        }
        settingDidChange(.networkMode(newNetworkMode))
    }

    func onApnInformation(modemId: UInt, mode: UInt, url: String!, username: String!, password: String!) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        settingDidChange(.apnConfiguration(mode == 1, url, username, password))
    }

    func onRegistrationInformation(modemId: UInt, status: ArsdkFeatureCellularRegistrationStatus,
                                   operator: String!, technology: ArsdkFeatureCellularTechnology) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        var newRegistrationStatus: CellularRegistrationStatus = .notRegistered
        switch status {
        case .notRegistered:
            newRegistrationStatus = .notRegistered
        case .denied:
            newRegistrationStatus = .denied
        case .registeredHome:
            newRegistrationStatus = .registeredHome
        case .registeredRoaming:
            newRegistrationStatus = .registeredRoaming
        case .searching:
            newRegistrationStatus = .searching
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown status, skipping this cellular Registration Information event.")
            return
        }
        var newTechnology: CellularTechnology = .edge
        switch technology {
        case .technology3g:
            newTechnology = .threeG
        case .technology4g:
            newTechnology = .fourG
        case .technology4gPlus:
            newTechnology = .fourGPlus
        case .technology5g:
            newTechnology = .fiveG
        case .technologyEdge:
            newTechnology = .edge
        case .technologyGprs:
            newTechnology = .gprs
        case .technologyGsm:
            newTechnology = .gsm
        case .technologyHsdpa:
            newTechnology = .hsdpa
        case .technologyHspa:
            newTechnology = .hspa
        case .technologyHsupa:
            newTechnology = .hsupa
        case .technologySdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown technology, skipping this cellular Registration Information event.")
            return
        }

        cellular.update(registrationStatus: newRegistrationStatus)
            .update(operator: `operator`)
            .update(technology: newTechnology)
            .notifyUpdated()
    }

    func onModemInformation(modemId: UInt, status: ArsdkFeatureCellularModemStatus, imei: String!) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        var newModemStatus: CellularModemStatus = .off
        switch status {
        case .off:
            newModemStatus = .off
        case .offline:
            newModemStatus = .offline
        case .online:
            newModemStatus = .online
        case .error:
            newModemStatus = .error
        case .flashing:
            newModemStatus = .updating
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown status, skipping this cellular Modem Information event.")
            return
        }
        cellular.update(modemStatus: newModemStatus)
            .update(imei: imei)
            .notifyUpdated()
        deviceStore.write(key: PersistedDataKey.imei, value: imei).commit()
    }

    func onPincodeRequest(modemId: UInt, invalidPincode: UInt, pinRemainingTries: UInt) {
        if modemId != MODEM_ID_MAIN {
            return
        }
        cellular.update(isPinCodeRequested: true)
            .update(isPinCodeInvalid: invalidPincode == 0 ? false : true)
            .update(pinRemainingTries: Int(pinRemainingTries))
            .notifyUpdated()
    }

    func onResetConfigFailed() {
        cellular.update(resetState: .failure).notifyUpdated()
        // failure state is transient, reset state to none
        cellular.update(resetState: .none).notifyUpdated()
    }
}

extension CellularSupportedCapabilities: ArsdkMappableEnum {

    /// Create set of cellular capabilites from all value set in a bitfield
    ///
    /// - Parameter bitField: arsdk bitfield
    /// - Returns: set containing all cellular capabilites set in bitField
    static func createSetFrom(bitField: UInt) -> Set<CellularSupportedCapabilities> {
        var result = Set<CellularSupportedCapabilities>()
        ArsdkFeatureCellularSupportedCapabilitiesBitField.forAllSet(in: UInt(bitField)) { arsdkValue in
            if let state = CellularSupportedCapabilities(fromArsdk: arsdkValue) {
                result.insert(state)
            }
        }
        return result
    }

    static var arsdkMapper = Mapper<CellularSupportedCapabilities, ArsdkFeatureCellularSupportedCapabilities>([
        .support4g: .capabilities4g])
}

// Extension to make CellularMode storable
extension CellularMode: StorableEnum {
    static var storableMapper = Mapper<CellularMode, String>([
        .disabled: "disabled",
        .nodata: "nodata",
        .data: "data"])
}

// Extension to make NetworkMode storable
extension CellularNetworkMode: StorableEnum {
    static var storableMapper = Mapper<CellularNetworkMode, String>([
        .auto: "auto",
        .mode3g: "mode3g",
        .mode4g: "mode4g",
        .mode5g: "mode5g"])
}

/// Store APN Configuration settings
private struct ApnConfigurationPresets {

    /// Settings data, storable
    struct Data: StorableType {
        /// Current manual flag
        var isManual = false
        /// Current url
        var url = ""
        /// Current username
        var username = ""
        /// Current password
        var password = ""
        /// Store keys
        private enum Key {
            static let isManual  = "isManual"
            static let url       = "url"
            static let username  = "username"
            static let password  = "password"
        }

        /// Constructor with default data
        init() {
        }

        /// Constructor from store data
        ///
        /// - Parameter content: store data
        init?(from content: AnyObject?) {
            if let content = StorableDict<String, AnyStorable>(from: content),
                let isManual = Bool(content[Key.isManual]),
                let url = String(content[Key.url]),
                let username = String(content[Key.username]),
                let password = String(content[Key.password]) {
                self.isManual = isManual
                self.url = url
                self.username = username
                self.password = password
            } else {
                return nil
            }
        }

        /// Convert data to storable
        ///
        /// - Returns: Storable containing data
        func asStorable() -> StorableProtocol {
            return StorableDict<String, AnyStorable>([
                Key.isManual: AnyStorable(isManual),
                Key.url: AnyStorable(url),
                Key.username: AnyStorable(username),
                Key.password: AnyStorable(password)])
        }
    }

    /// Settings data
    private(set) var data: Data

    /// APN settings
    private let apnSetting: ApnConfigurationSetting

    /// Constructor
    ///
    /// - Parameter apnSetting: APN settings
    init(apnSetting: ApnConfigurationSetting) {
        self.data = Data()
        self.apnSetting = apnSetting
    }

    /// is APN manual
    var isManual: Bool {
        return data.isManual
    }

    /// APN url
    var url: String {
        return data.url
    }

    /// APN username
    var username: String {
        return data.username
    }

    /// APN password
    var password: String {
        return data.password
    }

    /// Initialise from data
    ///
    /// - Parameter data: data to load
    mutating func load(data: Data) {
        self.data = data
    }

    /// Update
    ///
    /// - Parameters:
    ///   - isManual: new is APN manual
    ///   - url: new APN url
    ///   - username: new APN username
    ///   - password: new APN password
    mutating func update(isManual: Bool, url: String, username: String, password: String) {
        data.isManual = isManual
        data.url = url
        data.username = username
        data.password = password
    }
}
