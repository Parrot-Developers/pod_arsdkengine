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

/// Privacy controller backend that should be implemented by subclasses.
protocol PrivacyControllerBackend {

    /// Sends get state command.
    ///
    /// - Parameter getState: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(getState: Arsdk_Privacy_Command.GetState) -> Bool

    /// Sends log mode command.
    ///
    /// - Parameter setLogMode: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(setLogMode: Arsdk_Privacy_Command.SetLogMode) -> Bool

    /// Sends enable log encryption command.
    ///
    /// - Parameter setEnableLogEncryption: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(setEnableLogEncryption: Arsdk_Privacy_Command.EnableLogEncryption) -> Bool

    /// Sends disable log encryption command.
    ///
    /// - Parameter setDisableLogEncryption: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(setDisableLogEncryption: Arsdk_Privacy_Command.DisableLogEncryption) -> Bool
}

/// Controller for privacy related settings, like private mode.
class PrivacyController: DeviceComponentController {

    /// Privacy component
    private var privacy: PrivacyCore!

    /// User Account Utility.
    private var userAccountUtility: UserAccountUtilityCore?

    /// Monitor of the userAccount changes.
    private var userAccountMonitor: MonitorCore?

    /// Privacy controller backend.
    var backend: PrivacyControllerBackend!

    /// Whether `State` message has been received since `GetState` command was sent.
    private var stateReceived = false

    /// Whether connected device supports private mode.
    private var privateModeSupported = false

    /// Private mode value.
    private var privateMode = false

    /// component settings key
    private static let settingKey = "Privacy"

    /// Preset store for this component
    private var presetStore: SettingsStore?

    /// Device store for this component
    private var deviceStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case logEncryptionKey = "logEncryption"
    }

    /// Stored settings
    enum Setting: Hashable {
        case logEncryption(Bool)
        /// Setting storage key
        var key: SettingKey {
            switch self {
            case .logEncryption: return .logEncryptionKey
            }
        }
        /// All values to allow enumerating settings
        static let allCases: Set<Setting> = [.logEncryption(false)]

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
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: PrivacyController.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: PrivacyController.settingKey)
        }

        userAccountUtility = deviceController.engine.utilities.getUtility(Utilities.userAccount)

        super.init(deviceController: deviceController)
        privacy = PrivacyCore(store: deviceController.device.peripheralStore, backend: self)

        // load settings
        if deviceStore?.read(key: SettingKey.logEncryptionKey) == true {
            privacy.createEncryptionState()
        }

        loadPresets()
        if isPersisted {
            privacy.publish()
        }
    }

    /// Device is about to be connected.
    override func willConnect() {
        super.willConnect()
        droneSettings.removeAll()
        stateReceived = false
        _ = sendGetStateCommand()
    }

    /// Device is connected.
    override func didConnect() {
        userAccountMonitor = userAccountUtility?.startMonitoring(accountDidChange: { _ in
            self.applyPrivateModePreset()
        })
    }

    /// Device is disconnected.
    override func didDisconnect() {
        userAccountMonitor?.stop()
        userAccountMonitor = nil
        privacy.cancelSettingsRollback()
        if isPersisted {
            privacy.publish()
        } else {
            privacy.unpublish()
        }
    }

    override func backupLinkDidActivate() {
        super.backupLinkDidActivate()
        privacy.unpublish()
    }

    /// Applies presets.
    private func applyPrivateModePreset() {
        let userPrivateMode = userAccountUtility?.userAccountInfo?.privateMode ?? false
        if privateModeSupported && privateMode != userPrivateMode {
            _ = sendLogModeCommand(userPrivateMode)
            privateMode = userPrivateMode
        }
    }

    /// Load saved settings
    private func loadPresets() {
        if let presetStore = presetStore {
            Setting.allCases.forEach {
                switch $0 {
                case .logEncryption:
                    if let enabled: Bool = presetStore.read(key: $0.key) {
                        privacy.update(encryptionState: enabled)
                    }
                }
                privacy.notifyUpdated()
            }
        }
    }

    /// Called when a command that notify a setting change has been received
    ///
    /// - Parameter setting: setting that changed
    func settingDidChange(_ setting: Setting) {
        droneSettings.insert(setting)
        switch setting {
        case .logEncryption(let enabled):
            if connected {
                privacy.update(encryptionState: enabled).notifyUpdated()
            }
        }
    }

    /// Preset has been changed
    override func presetDidChange() {
        super.presetDidChange()
        // reload preset store
        presetStore = deviceController.presetStore.getSettingsStore(key: PrivacyController.settingKey)
        loadPresets()
        if connected {
            applyPresets()
        }
    }

    /// Applies all presets received during connection.
    private func applyPresets() {
        // iterate settings received during the connection
        for setting in droneSettings {
            switch setting {
            case .logEncryption(let enabled):
                if let preset: Bool = presetStore?.read(key: setting.key) {
                    if preset || enabled {
                        _ = sendEncryptionCommand(value: preset)
                    }
                    privacy.update(encryptionState: preset).notifyUpdated()
                } else {
                    if enabled {
                        _ = sendEnableLogEncryptionCommand()
                    }
                    privacy.update(encryptionState: enabled).notifyUpdated()
                }
            }
        }
    }
}

/// Extension for methods to send Privacy commands.
private extension PrivacyController {

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Privacy_Command.GetState()
        getState.includeDefaultCapabilities = true
        return backend.sendCommand(getState: getState)
    }

    /// Sends log mode command.
    ///
    /// - Parameter privateMode: requested private mode
    /// - Returns: `true` if the command has been sent
    func sendLogModeCommand(_ privateMode: Bool) -> Bool {
        var setLogMode = Arsdk_Privacy_Command.SetLogMode()
        setLogMode.logStorage = privateMode ? .none : .persistent
        setLogMode.logConfigPersistence = .persistent
        return backend.sendCommand(setLogMode: setLogMode)
    }

    /// Sends enable log encryption command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendEnableLogEncryptionCommand() -> Bool {
        let keyManager = deviceController.engine.utilities.getUtility(Utilities.keyManager)
        if let key = keyManager?.publicKey {
            var setEnableLogEncryption = Arsdk_Privacy_Command.EnableLogEncryption()
            setEnableLogEncryption.publicKey = key
            return backend.sendCommand(setEnableLogEncryption: setEnableLogEncryption)
        }
        return false
    }

    /// Sends disable log encryption command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendDisableLogEncryptionCommand() -> Bool {
        return backend.sendCommand(setDisableLogEncryption: Arsdk_Privacy_Command.DisableLogEncryption())
    }

    /// Sends encryption command.
    ///
    /// - Parameter value: `true` to enable log encryption, `false` to disable log encryption
    /// - Returns: `true` if the command has been sent
    func sendEncryptionCommand(value: Bool) -> Bool {
        if value {
            return sendEnableLogEncryptionCommand()
        } else {
            return sendDisableLogEncryptionCommand()
        }
    }
}

/// Extension for events processing.
extension PrivacyController {

    /// Processes a `State` event.
    ///
    /// - Parameter state: state to process
    func processState(_ state: Arsdk_Privacy_Event.State) {
        if state.hasDefaultCapabilities {
            privateModeSupported = state.defaultCapabilities.supportedLogStorage.contains(.none)
        }

        privateMode = state.logStorage == .none && state.logConfigPersistence == .persistent

        if state.hasLogEncryption {
            if !stateReceived {
                deviceStore?.write(key: SettingKey.logEncryptionKey, value: true).commit()
            }
            settingDidChange(.logEncryption(state.logEncryption.enabled))
        }

        if !stateReceived {
            stateReceived = true
            applyPrivateModePreset()
            applyPresets()
        }
        if state.hasLogEncryption {
            privacy.publish()
        }
    }
}

/// Privacy backend implementation.
extension PrivacyController: PrivacyBackend {
    func set(encryption: Bool) -> Bool {
        presetStore?.write(key: SettingKey.logEncryptionKey, value: encryption).commit()
        if connected {
            return sendEncryptionCommand(value: encryption)
        } else {
            privacy.update(encryptionState: encryption).notifyUpdated()
            return false
        }
    }
}
