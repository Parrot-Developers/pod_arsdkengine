// Copyright (C) 2024 Parrot Drones SAS
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
//

import Foundation
import GroundSdk

/// Offline backend of an EnumSetSetting
class OfflineEnumSetSetting<EnumType: Hashable>: OfflineSetting  where EnumType: StorableProtocol {

    /// Dictionary where available values are stored
    private let deviceDict: SettingsStore?

    /// Dictionary where preset values are stored
    private let presetDict: SettingsStore?

    /// Storage entry of the setting's preset values and available values
    private let entry: StoreKey

    /// Device setting backed by this offline setting
    private let setting: EnumSetSettingCore<EnumType>

    /// Function that notifies the component owning the setting
    private let notifyComponent: () -> Void

    /// Function that marks the change the component owning the setting
    private let markChanged: () -> Void

    /// Function that sends a new setting value to the device
    private let sendCommand: (Set<EnumType>) -> Bool

    /// Latest values received from or sent to the device.
    private var deviceValues: Set<EnumType>?

    /// Constructor
    ///
    /// - Parameters:
    ///   - deviceDict: dictionary where available values are stored
    ///   - presetDict: dictionary where preset values are stored
    ///   - entry: storage entry of the setting's preset values and available values
    ///   - setting: device setting backed by this offline setting
    ///   - notifyComponent: function that notifies the component owning the setting
    ///   - markChanged: function that marks the change the component owning the setting
    ///   - sendCommand: function that sends a new setting value to the device
    init(deviceDict: SettingsStore? = nil, presetDict: SettingsStore? =  nil, entry: StoreKey,
         setting: EnumSetSettingCore<EnumType>, notifyComponent: @escaping () -> Void,
         markChanged: @escaping () -> Void, sendCommand: @escaping (Set<EnumType>) -> Bool) {
        self.deviceDict = deviceDict
        self.presetDict = presetDict
        self.entry = entry
        self.setting = setting
        self.notifyComponent = notifyComponent
        self.markChanged = markChanged
        self.sendCommand = sendCommand

        if let availableValues: StorableArray<EnumType> = deviceDict?.read(key: entry) {
            _ = setting.update(supportedValues: Set(availableValues.storableValue))
        }
        if let values: StorableArray<EnumType> = presetDict?.read(key: entry) {
            _ = setting.update(values: Set(values.storableValue))
        }
    }

    public func resetDeviceValue() {
        deviceValues = nil
    }

    public func applyPreset() {
        if let values: StorableArray<EnumType> = presetDict?.read(key: entry) {
            _ = applyValues(values: Set(values.storableValue))
        }
    }

    /// Persists the given values and sends them to the device if it is connected, then updates the component's setting.
    ///
    /// - Parameter values: new values to set
    /// - Returns: `true` if the setting was forwarded to the device, otherwise `false`
    public func setValues(values: Set<EnumType>) -> Bool {
        let updating = applyValues(values: values)
        presetDict?.write(key: entry, value: StorableArray(Array(values))).commit()
        if !updating {
            notifyComponent()
        }
        return updating
    }

    /// Handles new available values received from the device.
    ///
    /// This function persists and updates the setting's available values.
    ///
    /// - Parameter values: new available values
    public func handleNewAvailableValues(values: Set<EnumType>) {
        deviceDict?.write(key: entry, value: StorableArray(Array(values))).commit()
        let changed = setting.update(supportedValues: values)
        if changed { markChanged() }
    }

    /// Handles new values received from the device.
    ///
    /// If the value is received for the first time, the persisted value is sent back to the device if it exists and it
    /// differs from the received one.
    ///
    /// - Parameter values: received values
    public func handleNewValues(values: Set<EnumType>?) {
        let sync = deviceValues == nil
        deviceValues = values

        if sync, let values: StorableArray<EnumType> = presetDict?.read(key: entry) {
            _ = applyValues(values: Set(values.storableValue))
        } else if let deviceValues = deviceValues {
            let changed = setting.update(values: deviceValues)
            if changed { markChanged() }
        }
    }

    /// Applies setting values.
    ///
    /// - Gets the last received values if the given one is `nil`
    /// - Sends the obtained values to the device in case it differs from the last received values;
    /// - Updates the component's setting accordingly.
    ///
    /// - Parameter values: new values to apply
    /// - Returns: `true` if a command was sent to the device and the component's setting should arm its updating flag
    private func applyValues(values: Set<EnumType>?) -> Bool {
        guard let newValues = values ?? deviceValues else { return false }

        let updating = newValues != deviceValues && sendCommand(newValues)
        deviceValues = newValues
        let changed = setting.update(values: newValues)
        if changed { markChanged() }
        return updating
    }
}
