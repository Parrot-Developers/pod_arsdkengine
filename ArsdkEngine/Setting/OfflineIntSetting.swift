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

import GroundSdk

/// Offline backend of an IntSetting
class OfflineIntSetting: OfflineSetting {

    /// Dictionary where bounds are stored
    private let deviceDict: SettingsStore?

    /// Dictionary where preset value is stored
    private let presetDict: SettingsStore?

    /// Storage entry of the setting's preset value and bounds
    private let entry: StoreKey

    /// Device setting backed by this offline setting
    private let setting: IntSettingCore

    /// Function that notifies the component owning the setting
    private let notifyComponent: () -> Void

    /// Function that marks the change the component owning the setting
    private let markChanged: () -> Void

    /// Function that sends a new setting value to the device
    private let sendCommand: (Int) -> Bool

    /// Latest value received from or sent to the device.
    private var deviceValue: Int?

    /// Constructor
    ///
    /// - Parameters:
    ///   - deviceDict: dictionary where bounds are stored
    ///   - presetDict: dictionary where preset value is stored
    ///   - entry: storage entry of the setting's preset value and bounds
    ///   - setting: device setting backed by this offline setting
    ///   - notifyComponent: function that notifies the component owning the setting
    ///   - markChanged: function that marks the change the component owning the setting
    ///   - sendCommand: function that sends a new setting value to the device
    init(deviceDict: SettingsStore? = nil, presetDict: SettingsStore? =  nil,
         entry: StoreKey, setting: IntSettingCore, notifyComponent: @escaping () -> Void,
         markChanged: @escaping () -> Void, sendCommand: @escaping (Int) -> Bool) {
        self.deviceDict = deviceDict
        self.presetDict = presetDict
        self.entry = entry
        self.setting = setting
        self.notifyComponent = notifyComponent
        self.markChanged = markChanged
        self.sendCommand = sendCommand

        if let value: Int = presetDict?.read(key: entry),
           let range: (min: Int, max: Int) = deviceDict?.readRange(key: entry) {
            _ = setting.update(min: range.min, value: value, max: range.max)
        }
    }

    public func resetDeviceValue() {
        deviceValue = nil
    }

    public func applyPreset() {
       _ = applyValue(value: presetDict?.read(key: entry))
    }

    /// Persists the given value and sends it to the device if it is connected, then updates the component's setting.
    ///
    /// - Parameter value: new value to set
    /// - Returns: `true` if the setting was forwarded to the device, otherwise `false`
    public func setValue(value: Int) -> Bool {
        let updating: Bool = applyValue(value: value)
        presetDict?.write(key: entry, value: value).commit()
        if !updating {
            notifyComponent()
        }
        return updating
    }

    /// Handles new bounds received from the device.
    ///
    /// This function persists and updates the setting's bounds.
    ///
    /// - Parameters:
    ///   - min: range min value
    ///   - max: range max value
    public func handleNewBounds(min: Int, max: Int) {
        deviceDict?.writeRange(key: entry, min: min, max: max).commit()
        let changed = setting.update(min: min, value: nil, max: max)
        if changed { markChanged() }
    }

    /// Handles new value received from the device.
    ///
    /// If the value is received for the first time, the persisted value is sent back to the device if it exists and it
    /// differs from the received one.
    ///
    /// - Parameter value: received value
    public func handleNewValue(value: Int?) {
        let sync = deviceValue == nil
        deviceValue = value

        if sync {
            _ = applyValue(value: presetDict?.read(key: entry))
        } else if let deviceValue = deviceValue {
            let changed = setting.update(min: nil, value: deviceValue, max: nil)
            if changed { markChanged() }
        }
    }

    /// Applies setting value.
    ///
    /// - Gets the last received value if the given one is `nil`
    /// - Sends the obtained value to the device in case it differs from the last received value;
    /// - Updates the component's setting accordingly.
    ///
    /// - Parameter value: new value to apply
    /// - Returns: `true` if a command was sent to the device and the component's setting should arm its updating flag
    private func applyValue(value: Int?) -> Bool {
        guard let newValue = value ?? deviceValue else { return false }

        let updating = newValue != deviceValue && sendCommand(newValue)
        deviceValue = newValue
        let changed = setting.update(min: nil, value: newValue, max: nil)
        if changed { markChanged() }
        return updating
    }
}
