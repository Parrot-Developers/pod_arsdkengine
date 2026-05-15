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

import Foundation
import GroundSdk
import SwiftProtobuf

/// UnguardedFlight component controller for Anafi family drones.
class AnafiUnguardedFlight: DeviceComponentController, UnguardedFlightBackend {
    /// Component settings key
    private static let settingKey = "UnguardedFlight"

    /// All settings that can be stored
    enum SettingKey: String, StoreKey {
        case elementsKey = "elements"
    }

    /// Decoder for Unguarded flight events.
    private var arsdkDecoder: ArsdkUnguardedflightEventDecoder!

    /// Unguarded flight component
    private var component: UnguardedFlightCore!

    /// Store device specific values
    private let deviceStore: SettingsStore?

    /// Preset store for this piloting interface
    private var presetStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { deviceStore?.new == false }

    /// Received elements value.
    private var receivedElements: Set<UnguardedFlightElement>?

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        if GroundSdkConfig.sharedInstance.offlineSettings == .off {
            deviceStore = nil
            presetStore = nil
        } else {
            deviceStore = deviceController.deviceStore.getSettingsStore(key: AnafiUnguardedFlight.settingKey)
            presetStore = deviceController.presetStore.getSettingsStore(key: AnafiUnguardedFlight.settingKey)
        }

        super.init(deviceController: deviceController)
        arsdkDecoder = ArsdkUnguardedflightEventDecoder(listener: self)
        component = UnguardedFlightCore(store: deviceController.device.peripheralStore,
                                        backend: self)

        loadPresets()
        if isPersisted {
            component.publish()
        }
    }

    override func willConnect() {
        receivedElements = nil
        _ = sendUnguardedFlightCommand(.getCapabilities(Google_Protobuf_Empty()))
        _ = sendUnguardedFlightCommand(.getConfig(Google_Protobuf_Empty()))
    }

    override func didDisconnect() {
        component.cancelSettingsRollback()
        if isPersisted {
            component.publish()
        } else {
            component.unpublish()
        }
    }

    override func backupLinkDidActivate() {
        super.backupLinkDidActivate()
        component.unpublish()
    }

    override func presetDidChange() {
        if connected {
            applyPresets()
            component.notifyUpdated()
        }
    }

    override func willForget() {
        component.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }

    /// Load saved elements.
    private func loadPresets() {
        if let presetStore = presetStore, let deviceStore = deviceStore {
            if let elementsValues: StorableArray<UnguardedFlightElement> =
                presetStore.read(key: SettingKey.elementsKey) {
                component.update(elements: Set(elementsValues.storableValue))
            }

            if let supportedElements: StorableArray<UnguardedFlightElement> =
                deviceStore.read(key: SettingKey.elementsKey) {
                component.update(supportedElements: Set(supportedElements.storableValue))
            }

            component.notifyUpdated()
        }
    }

    /// Apply a preset
    ///
    /// Iterate settings received during connection
    private func applyPresets() {
        if let presetStore = presetStore {
            if let elementsValues: StorableArray<UnguardedFlightElement> =
                presetStore.read(key: SettingKey.elementsKey) {
                applyElements(elements: Set(elementsValues.storableValue))
            }
        }
    }

    /// Applies elements.
    ///
    /// Gets the last received value if the given one is null;
    /// Sends the obtained value to the drone in case it differs from the last received value;
    /// Updates the component's setting accordingly.
    ///
    /// - Parameter elements: elements to apply
    private func applyElements(elements: Set<UnguardedFlightElement>?) {
        guard let newElements = elements ?? receivedElements else { return }

        if newElements != receivedElements {
            var setConfig = Arsdk_Unguardedflight_Config()
            setConfig.unguardedFlightElements = newElements.compactMap { $0.arsdkValue }
            _ = sendUnguardedFlightCommand(.setConfig(setConfig))
        }

        component.update(elements: newElements)
    }
}

/// Unguarded flight listener implementation
extension AnafiUnguardedFlight: ArsdkUnguardedflightEventDecoderListener {

    func onCapabilities(_ capabilities: Arsdk_Unguardedflight_Config) {
        let elements  = capabilities.unguardedFlightElements.compactMap { UnguardedFlightElement(fromArsdk: $0) }
        component.update(supportedElements: Set(elements))
        deviceStore?.write(key: SettingKey.elementsKey, value: StorableArray(Array(elements))).commit()
        component.publish()
    }

    func onCurrentConfig(_ currentConfig: Arsdk_Unguardedflight_Config) {
        let sync = receivedElements == nil
        receivedElements = Set(currentConfig.unguardedFlightElements
            .compactMap { UnguardedFlightElement(fromArsdk: $0) })

        if sync {
            let elementsValues: StorableArray<UnguardedFlightElement>? =
            presetStore?.read(key: SettingKey.elementsKey)
            let elements = elementsValues == nil ? nil : Set(elementsValues!.storableValue)
            applyElements(elements: elements)

        } else {
            component.update(elements: receivedElements ?? [])
        }
        component.notifyUpdated()
    }
}

/// Unguarded flight backend implementation
extension AnafiUnguardedFlight {
    func selectElements(elements: Set<UnguardedFlightElement>) -> Bool {
        presetStore?.write(key: SettingKey.elementsKey, value: StorableArray(Array(elements))).commit()
        if connected {
            applyElements(elements: elements)
            return true
        } else {
            component.update(elements: elements).notifyUpdated()
            return false
        }
    }
}

/// Extension for methods to send Unguarded flight commands.
extension AnafiUnguardedFlight {

    /// Sends to the drone an unguarded flight command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendUnguardedFlightCommand(_ command: Arsdk_Unguardedflight_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkUnguardedflightCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension to make UnguardedFlightElement storable
extension UnguardedFlightElement: StorableEnum {
    static var storableMapper = Mapper<UnguardedFlightElement, String>([
        .takeOffReady: "takeOffReady",
        .autoLanding: "autoLanding",
        .autoRth: "autoRth",
        .tofLed: "tofLed"])
}

/// Extension that adds conversion from/to arsdk enum.
extension UnguardedFlightElement: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<UnguardedFlightElement, Arsdk_Unguardedflight_UnguardedFlightElement>([
        .takeOffReady: .takeoffReady,
        .autoLanding: .autoland,
        .autoRth: .autorth,
        .tofLed: .tofLed
    ])
}
