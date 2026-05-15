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

/// Mars slave command delegate.
protocol MarsSlaveCommandDelegate: AnyObject {

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

/// Mars radio slave component controller.
class MarsSlaveController: RadioComponentController {

    /// Mars slave component.
    private var marsSlave: MarsSlaveCore!

    /// Command delegate.
    private unowned let delegate: MarsSlaveCommandDelegate

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
    init(store: ComponentStoreCore, utilities: UtilityCoreRegistry, delegate: MarsSlaveCommandDelegate,
         radioId: UInt32) {
        self.delegate = delegate
        self.radioId = radioId
        self.reverseGeocoderUtility = utilities.getUtility(Utilities.reverseGeocoder)
        self.marsSlave = MarsSlaveCore(store: store, backend: self)
    }

    func didDisconnect() {
        stateReceived = false
        marsSlave.cancelSettingsRollback()
        marsSlave.unpublish()
        reverseGeocoderMonitor?.stop()
        reverseGeocoderMonitor = nil
    }

    func processStateEvent(state: Arsdk_Connectivity_Event.State) {
        // capabilities
        if state.hasDefaultCapabilities {
            let capabilities = state.defaultCapabilities

            let modes = Set(capabilities.supportedEncryptionTypes.compactMap(MarsSecurityMode.init(fromArsdk:)))
            marsSlave.update(supportedSecurityModes: modes)

            let countries = Set(capabilities.supportedCountries.compactMap(Country.init(rawValue:)))
            marsSlave.update(supportedCountries: countries)
        }

        // config
        if state.hasStationConfig {
            let config = state.stationConfig

            if config.hasEnvironment,
               let environment = Environment(fromArsdk: config.environment.value) {
                marsSlave.update(environment: environment)
            }

            if config.hasCountry,
               let country = Country(rawValue: config.country.value) {
                if GroundSdkConfig.sharedInstance.autoSelectMarsCountry {
                    marsSlave.update(supportedCountries: [country])
                }
                marsSlave.update(country: country)
            }

            if config.hasSecurity,
               let arsdkMode = config.security.encryption.first,
               let mode = MarsSecurityMode(fromArsdk: arsdkMode) {
                marsSlave.update(security: mode)
            }

            switch config.channelSelectionType {
            case .manualChannel:
                marsSlave.update(channelSelectionMode: .manual)
            case .automaticChannel(let selectionMode):
                let bands = Set(selectionMode.allowedBands.compactMap(MarsBand.init(fromArsdk:)))
                marsSlave.update(channelSelectionMode: .autoOnBands(bands: bands))
            case .frequencyHoppingList(let frequencyHoppingList):
                let rxChannels = Set(frequencyHoppingList.rxChannels.compactMap(MarsChannel.init(fromArsdk:)))
                let txChannels = Set(frequencyHoppingList.txChannels.compactMap(MarsChannel.init(fromArsdk:)))
                marsSlave.update(
                    channelSelectionMode: .autoOnChannels(rxChannels: rxChannels, txChannels: txChannels))
            case .none:
                break
            }
        }

        // authorized channels
        switch (state.authorizedChannelsType) {
        case .authorizedPackedChannels:
            let channels = state.authorizedPackedChannels.channels.compactMap { MarsChannel.fromArsdk($0) }.joined()
            marsSlave.update(availableChannels: Set(channels))

            let bands = channels.compactMap { $0.band }
            marsSlave.update(availableBands: Set(bands))
        case .authorizedChannels:
            let channels = state.authorizedChannels.channel.compactMap { MarsChannel(fromArsdk: $0) }
            marsSlave.update(availableChannels: Set(channels))

            let bands = channels.compactMap { $0.band }
            marsSlave.update(availableBands: Set(bands))
        default:
            break
        }

        // channel
        if state.hasChannel,
           let marsChannel = MarsChannel(fromArsdk: state.channel) {
            let channel = marsSlave.channel.availableChannels
                .first { $0.id == marsChannel.id } ?? marsChannel
            marsSlave.update(channel: channel)
        }

        // mode
        if let mode = state.mode {
            if case .station = mode {
                marsSlave.update(active: true)
            } else {
                marsSlave.update(active: false)
            }
        }

        // check autoSelectCountry config
        if !stateReceived {
            stateReceived = true
            manageAutoSelectCountry()
        }

        marsSlave.publish()
    }

    func processSystemEvent(state: Arsdk_System_Event.State) {}

    /// Checks `autoSelectMarsCountry` flag in configuration, and enables this feature, when appropriate.
    private func manageAutoSelectCountry() {
        if GroundSdkConfig.sharedInstance.autoSelectMarsCountry {
            // force environment to outdoor
            if marsSlave.environment.value != .outdoor {
                _ = set(environment: .outdoor)
            }
            marsSlave.update(supportedEnvironments: [.outdoor])

            // monitor reverseGeocoder
            reverseGeocoderMonitor = reverseGeocoderUtility?
                .startReverseGeocoderMonitoring { [unowned self] placemark in
                    if let isoCountryCode = placemark?.isoCountryCode?.uppercased(),
                       let country = Country(rawValue: isoCountryCode),
                       isoCountryCode != self.marsSlave.country.value.rawValue {
                        _ = self.set(country: country)
                    }
                }

            // force country to the one found by reverse geocoding location
            if let isoCountryCode = reverseGeocoderUtility?.placemark?.isoCountryCode?.uppercased(),
               let country = Country(rawValue: isoCountryCode) {
                marsSlave.update(supportedCountries: [country])
            }
        }
    }
}

/// Mars slave backend implementation.
extension MarsSlaveController: MarsSlaveBackend {

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

    func select(channel: MarsChannel) -> Bool {
        guard let arsdkChannel = channel.arsdkValue else { return false }

        var config = Arsdk_Connectivity_StationConfig()
        config.channelSelectionType = .manualChannel(arsdkChannel)
        return delegate.configure(radioId: radioId, config: config)
    }

    func autoSelectChannel(onBands bands: Set<MarsBand>) -> Bool {
        var selection = Arsdk_Connectivity_AutomaticChannelSelection()
        selection.allowedBands = bands.sorted().compactMap { $0.arsdkValue }
        var config = Arsdk_Connectivity_StationConfig()
        config.channelSelectionType = .automaticChannel(selection)
        return delegate.configure(radioId: radioId, config: config)
    }

    func autoSelectChannel(rxChannels: Set<MarsChannel>, txChannels: Set<MarsChannel>) -> Bool {
        var list = Arsdk_Connectivity_FrequencyHoppingList()
        list.rxChannels = rxChannels.compactMap { $0.arsdkValue }
        list.txChannels = txChannels.compactMap { $0.arsdkValue }
        var config = Arsdk_Connectivity_StationConfig()
        config.channelSelectionType = .frequencyHoppingList(list)
        return delegate.configure(radioId: radioId, config: config)
    }

    func set(security: MarsSecurityMode, password: String?) -> Bool {
        guard let encryption = security.arsdkValue else { return false }

        var config = Arsdk_Connectivity_StationConfig()
        config.security = Arsdk_Connectivity_NetworkSecurityMode()
        config.security.encryption = [encryption]
        config.security.passphrase = password ?? ""
        return delegate.configure(radioId: radioId, config: config)
    }
}
