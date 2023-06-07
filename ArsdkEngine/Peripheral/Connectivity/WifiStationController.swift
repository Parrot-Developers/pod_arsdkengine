// Copyright (C) 2023 Parrot Drones SAS
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

/// Wifi station command delegate.
protocol WifiStationCommandDelegate: AnyObject {

    /// Sends command to set mode of radio with given id.
    ///
    /// - Parameters:
    ///   - radioId: radio identifier
    ///   - mode: new connectivity mode
    /// - Returns: `true` if the command has been sent, `false` otherwise
    func set(radioId: UInt32, mode: Arsdk_Connectivity_Mode) -> Bool

    /// Sends command to configure radio with given id.
    ///
    /// - Parameters:
    ///   - radioId: radio identifier
    ///   - config: new configuration
    /// - Returns: `true` if the command has been sent, `false` otherwise
    func configure(radioId: UInt32, config: Arsdk_Connectivity_StationConfig) -> Bool
}

/// Wifi radio station component controller.
class WifiStationController: RadioComponentController {

    /// Wifi station component.
    private var wifiStation: WifiStationCore!

    /// Command delegate.
    private unowned let delegate: WifiStationCommandDelegate

    /// Radio identifier.
    private let radioId: UInt32

    /// Constructor.
    ///
    /// - Parameters:
    ///    - store: store where the peripheral will be stored
    ///    - delegate: command delegate
    ///    - radioId: identifies the radio this component belongs to
    init(store: ComponentStoreCore, delegate: WifiStationCommandDelegate, radioId: UInt32) {
        self.delegate = delegate
        self.radioId = radioId
        self.wifiStation = WifiStationCore(store: store, backend: self)
    }

    func didDisconnect() {
        wifiStation.cancelSettingsRollback()
        wifiStation.unpublish()
    }

    func processStateEvent(state: Arsdk_Connectivity_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            let capabilities = state.defaultCapabilities

            let modes = Set(capabilities.supportedEncryptionTypes.compactMap(SecurityMode.init(fromArsdk:)))
            wifiStation.update(supportedSecurityModes: modes)

            let countries = Set(capabilities.supportedCountries.compactMap(Country.init(rawValue:)))
            wifiStation.update(supportedCountries: countries)
        }

        // config
        if state.hasStationConfig {
            let config = state.stationConfig

            if config.hasEnvironment,
               let environment = Environment(fromArsdk: config.environment.value) {
                wifiStation.update(environment: environment)
            }

            if config.hasCountry,
               let country = Country(rawValue: config.country.value) {
                wifiStation.update(country: country)
            }

            if config.hasSsid {
                wifiStation.update(ssid: config.ssid.value)
            }

            if config.hasHidden {
                wifiStation.update(ssidBroadcast: !config.hidden.value)
            }

            if config.hasSecurity,
               let arsdkMode = config.security.encryption.first,
               let mode = SecurityMode(fromArsdk: arsdkMode) {
                wifiStation.update(security: mode)
            }
        }

        // mode
        if let mode = state.mode {
            if case .station = mode {
                wifiStation.update(active: true)
            } else {
                wifiStation.update(active: false)
            }
        }

        wifiStation.publish()
        wifiStation.notifyUpdated()
    }
}

/// Wifi station backend implementation.
extension WifiStationController: WifiStationBackend {

    func set(active: Bool) -> Bool {
        delegate.set(radioId: radioId, mode: active ? .sta : .idle)
    }

    func set(environment: Environment) -> Bool {
        guard let arsdkEnvironment = environment.arsdkValue else { return false }

        var config = Arsdk_Connectivity_StationConfig()
        config.environment = Arsdk_Connectivity_EnvironmentValue()
        config.environment.value = arsdkEnvironment
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(country: Country) -> Bool {
        var config = Arsdk_Connectivity_StationConfig()
        config.country.value = country.rawValue
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(ssid: String) -> Bool {
        var config = Arsdk_Connectivity_StationConfig()
        config.ssid.value = ssid
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(ssidBroadcast: Bool) -> Bool {
        var config = Arsdk_Connectivity_StationConfig()
        config.hidden.value = !ssidBroadcast
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(security: SecurityMode, password: String?) -> Bool {
        guard let encryption = security.arsdkValue else { return false }

        var config = Arsdk_Connectivity_StationConfig()
        config.security = Arsdk_Connectivity_NetworkSecurityMode()
        config.security.encryption = [encryption]
        config.security.passphrase = password ?? ""
        return delegate.configure(radioId: radioId, config: config)
    }
}
