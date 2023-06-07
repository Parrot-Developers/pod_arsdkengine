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

/// Wifi access point command delegate.
protocol WifiAccessPointCommandDelegate: AnyObject {

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
    func configure(radioId: UInt32, config: Arsdk_Connectivity_AccessPointConfig) -> Bool
}

/// Wifi radio access point component controller.
class WifiAccessPointController: RadioComponentController {

    /// Wifi access point component.
    private var wifiAccessPoint: WifiAccessPointCore!

    /// Command delegate.
    private unowned let delegate: WifiAccessPointCommandDelegate

    /// Radio identifier.
    private let radioId: UInt32

    /// Whether state event has been received since connection to drone.
    private var stateReceived = false

    /// Reverse geocoder utility.
    private var reverseGeocoderUtility: ReverseGeocoderUtilityCore?

    /// Reverse geocoder monitor.
    private var reverseGeocoderMonitor: MonitorCore?

    /// Constructor.
    ///
    /// - Parameters:
    ///    - store: store where the peripheral will be stored
    ///    - utilities: utility registry
    ///    - delegate: command delegate
    ///    - radioId: identifies the radio this component belongs to
    init(store: ComponentStoreCore, utilities: UtilityCoreRegistry, delegate: WifiAccessPointCommandDelegate,
         radioId: UInt32) {
        self.delegate = delegate
        self.radioId = radioId
        self.reverseGeocoderUtility = utilities.getUtility(Utilities.reverseGeocoder)
        self.wifiAccessPoint = WifiAccessPointCore(store: store, backend: self)
    }

    func didDisconnect() {
        stateReceived = false
        wifiAccessPoint.cancelSettingsRollback()
        wifiAccessPoint.unpublish()
        reverseGeocoderMonitor?.stop()
        reverseGeocoderMonitor = nil
    }

    func processStateEvent(state: Arsdk_Connectivity_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            let capabilities = state.defaultCapabilities

            let modes = Set(capabilities.supportedEncryptionTypes.compactMap(SecurityMode.init(fromArsdk:)))
            wifiAccessPoint.update(supportedSecurityModes: modes)

            let countries = Set(capabilities.supportedCountries.compactMap(Country.init(rawValue:)))
            wifiAccessPoint.update(supportedCountries: countries)
        }

        // config
        if state.hasAccessPointConfig {
            let config = state.accessPointConfig

            if config.hasEnvironment,
               let environment = Environment(fromArsdk: config.environment.value) {
                wifiAccessPoint.update(environment: environment)
            }

            if config.hasCountry,
               let country = Country(rawValue: config.country.value) {
                wifiAccessPoint.update(country: country)

                if GroundSdkConfig.sharedInstance.autoSelectWifiCountry {
                    wifiAccessPoint.update(supportedCountries: [country])
                }
            }

            if config.hasSsid {
                wifiAccessPoint.update(ssid: config.ssid.value)
            }

            if config.hasHidden {
                wifiAccessPoint.update(ssidBroadcast: !config.hidden.value)
            }

            if config.hasSecurity {
                let modes = Set(config.security.encryption.compactMap(SecurityMode.init(fromArsdk:)))
                wifiAccessPoint.update(security: modes)
            }

            switch config.channelSelectionType {
            case .manualChannel:
                wifiAccessPoint.update(selectionMode: .manual)
            case .automaticChannel(let selectionMode):
                let bands = Set(selectionMode.allowedBands.compactMap(Band.init(fromArsdk:)))
                if bands == [.band_2_4_Ghz, .band_5_Ghz] {
                    wifiAccessPoint.update(selectionMode: .autoAnyBand)
                } else if bands.contains(.band_2_4_Ghz) {
                    wifiAccessPoint.update(selectionMode: .auto2_4GhzBand)
                } else if bands.contains(.band_5_Ghz) {
                    wifiAccessPoint.update(selectionMode: .auto5GhzBand)
                }
            case .none:
                break
            }
        }

        // channel
        if state.hasChannel,
           case .wifiChannel(let arsdkChannel) = state.channel.type,
           let wifiChannel = WifiChannel(fromArsdk: arsdkChannel) {
            wifiAccessPoint.update(channel: wifiChannel)
        }

        // authorized channels
        if state.hasAuthorizedChannels {
            let channels = state.authorizedChannels.channel.filter {
                // assume that the device always sends an authorizedChannels update when we change the environment
                Environment(fromArsdk: $0.environment) == wifiAccessPoint.environment.value
            }.compactMap {
                if $0.hasChannel,
                   case .wifiChannel(let arsdkChannel) = $0.channel.type {
                    return WifiChannel(fromArsdk: arsdkChannel)
                }
                return nil
            }
            wifiAccessPoint.update(availableChannels: Set(channels))
        }

        // mode
        if let mode = state.mode {
            if case .accessPoint = mode {
                wifiAccessPoint.update(active: true)
            } else {
                wifiAccessPoint.update(active: false)
            }
        }

        // check autoSelectWifiCountry config
        if !stateReceived {
            stateReceived = true
            manageAutoSelectWifiCountry()
        }

        wifiAccessPoint.publish()
        wifiAccessPoint.notifyUpdated()
    }

    /// Checks `autoSelectWifiCountry` flag in configuartion, and enables this feature, when appropriate.
    private func manageAutoSelectWifiCountry() {
        if GroundSdkConfig.sharedInstance.autoSelectWifiCountry {
            // force environment to outdoor
            if wifiAccessPoint.environment.value != .outdoor {
                _ = set(environment: .outdoor)
            }
            wifiAccessPoint.update(supportedEnvironments: [.outdoor])

            // monitor reverseGeocoder
            reverseGeocoderMonitor = reverseGeocoderUtility?
                .startReverseGeocoderMonitoring { [unowned self] placemark in
                    if let isoCountryCode = placemark?.isoCountryCode?.uppercased(),
                       let country = Country(rawValue: isoCountryCode),
                       isoCountryCode != self.wifiAccessPoint.country.value.rawValue {
                        _ = self.set(country: country)
                    }
            }

            // force country to the one found by reverse geocoding location
            if let isoCountryCode = reverseGeocoderUtility?.placemark?.isoCountryCode?.uppercased(),
               let country = Country(rawValue: isoCountryCode) {
                wifiAccessPoint.update(supportedCountries: [country])
            }
        }
    }
}

/// Wifi access point backend implementation.
extension WifiAccessPointController: WifiAccessPointBackend {

    func set(active: Bool) -> Bool {
        delegate.set(radioId: radioId, mode: active ? .ap : .idle)
    }

    func set(environment: Environment) -> Bool {
        guard let arsdkEnvironment = environment.arsdkValue else { return false }

        var config = Arsdk_Connectivity_AccessPointConfig()
        config.environment = Arsdk_Connectivity_EnvironmentValue()
        config.environment.value = arsdkEnvironment
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(country: Country) -> Bool {
        var config = Arsdk_Connectivity_AccessPointConfig()
        config.country.value = country.rawValue
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(ssid: String) -> Bool {
        var config = Arsdk_Connectivity_AccessPointConfig()
        config.ssid.value = ssid
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(ssidBroadcast: Bool) -> Bool {
        var config = Arsdk_Connectivity_AccessPointConfig()
        config.hidden.value = !ssidBroadcast
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(security: Set<SecurityMode>, password: String?) -> Bool {
        let encryptions = security.compactMap { $0.arsdkValue }
        guard !encryptions.isEmpty else { return false }

        var config = Arsdk_Connectivity_AccessPointConfig()
        config.security = Arsdk_Connectivity_NetworkSecurityMode()
        config.security.encryption = encryptions
        config.security.passphrase = password ?? ""
        return delegate.configure(radioId: radioId, config: config)
    }

    func select(channel: WifiChannel) -> Bool {
        guard let arsdkBand = channel.getBand().arsdkValue else { return false }

        var arsdkWifiChannel = Arsdk_Connectivity_WifiChannel()
        arsdkWifiChannel.band = arsdkBand
        arsdkWifiChannel.channel = UInt32(channel.getChannelId())
        var arsdkChannel = Arsdk_Connectivity_Channel()
        arsdkChannel.type = .wifiChannel(arsdkWifiChannel)
        var config = Arsdk_Connectivity_AccessPointConfig()
        config.channelSelectionType = .manualChannel(arsdkChannel)
        return delegate.configure(radioId: radioId, config: config)
    }

    func autoSelectChannel(onBand band: Band?) -> Bool {
        var selection = Arsdk_Connectivity_AutomaticChannelSelection()
        if let arsdkBand = band?.arsdkValue {
            selection.allowedBands = [arsdkBand]
        } else {
            selection.allowedBands = [.wifiBand24Ghz, .wifiBand5Ghz]
        }
        var config = Arsdk_Connectivity_AccessPointConfig()
        config.channelSelectionType = .automaticChannel(selection)
        return delegate.configure(radioId: radioId, config: config)
    }
}
