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
import SwiftProtobuf

/// Controller for navigation control peripheral.
class AnafiNavigationController: DeviceComponentController {

    /// Main key in the device store
    private static let settingKey = "navigationControl"

    /// All data that can be stored
    private enum PersistedDataKey: String, StoreKey {
        case latitude = "latitude"
        case longitude = "longitude"
        case altitude = "altitude"
        case heading = "heading"
        case horizontalAccuracy = "horizontalAccuracy"
        case verticalAccuracy = "verticalAccuracy"
        case headingAccuracy = "headingAccuracy"
        case timestamp = "timestamp"
        case sources = "sources"
    }

    typealias Command = Arsdk_Navigation_Command
    typealias Event = Arsdk_Navigation_Event
    typealias Encoder = ArsdkNavigationCommandEncoder
    typealias Decoder = ArsdkNavigationEventDecoder

    private var arsdkBackupLinkDecoder: ArsdkBackuplinkEventDecoder!

    /// Special value returned by `latitude` or `longitude` when the coordinate is not known.
    private static let UnknownCoordinate: Double = 500

    /// Whether ArsdkNavigation messages are supported by the drone
    private var arsdkNavigationSupported = false

    /// Latest GPS fix received from legacy arsdk event.
    private var latestGpsFix = false

    /// Latest satellite count received from legacy arsdk event.
    private var latestSatelliteCount: Int?

    /// Navigation Control component
    private(set) var peripheral: NavigationControlCore!

    /// Store device specific values, like last position
    private let deviceStore: SettingsStore

    /// Preset store for this peripheral
    private var presetStore: SettingsStore?

    /// `true` if this controller has persisted device specific values
    private var isPersisted: Bool { !deviceStore.new }

    /// Received sources value.
    private var receivedSources: Set<Source>?

    /// Decoder for navigation events.
    private var arsdkDecoder: Decoder!

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        deviceStore = deviceController.deviceStore.getSettingsStore(key: AnafiNavigationController.settingKey)
        if GroundSdkConfig.sharedInstance.offlineSettings == .model {
            presetStore = deviceController.presetStore.getSettingsStore(key: AnafiNavigationController.settingKey)
        }

        super.init(deviceController: deviceController)

        arsdkBackupLinkDecoder = ArsdkBackuplinkEventDecoder(listener: self)
        arsdkDecoder = Decoder(listener: self)
        peripheral = NavigationControlCore(store: deviceController.device.peripheralStore,
                                           backend: self)

        if isPersisted {
            loadPersistedData()
            peripheral.publish()
        }
    }

    /// Drone is about to be forgotten.
    override func willForget() {
        peripheral.unpublish()
    }

    /// Drone is about to be connected.
    override func willConnect() {
        receivedSources = nil
        _ = sendGetStateCommand()
    }

    /// Drone is connected
    override func didConnect() {
        peripheral.publish()
    }

    /// Drone is disconnected.
    override func didDisconnect() {
        peripheral.update(state: NavigationControlState(availableFrames: []))
            .update(hasCurrentLocation: false)
            .update(gnssInfo: nil)
            .update(reliability: nil)
            .update(usesMagnetometer: nil)
            .update(gnssSource: nil)
            .publish()
        arsdkNavigationSupported = false
        latestGpsFix = false
        latestSatelliteCount = nil
    }

    /// Backup link is active
    override func backupLinkDidActivate() {
        peripheral.update(state: NavigationControlState(availableFrames: []))
            .update(gnssSource: nil)
            .publish()
    }

    override func presetDidChange() {
        presetStore = deviceController.presetStore.getSettingsStore(key: AnafiNavigationController.settingKey)
        if connected {
            applyPresets()
        }
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3PilotingstateUid {
            ArsdkFeatureArdrone3Pilotingstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3GpsstateUid {
            ArsdkFeatureArdrone3Gpsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureArdrone3GpssettingsstateUid {
            ArsdkFeatureArdrone3Gpssettingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            arsdkDecoder.decode(command)
            arsdkBackupLinkDecoder.decode(command)
        }
    }

    /// Load saved values
    private func loadPersistedData() {
        // load location
        if let latitude: Double = deviceStore.read(key: PersistedDataKey.latitude),
           let longitude: Double = deviceStore.read(key: PersistedDataKey.longitude),
           let date: Date = deviceStore.read(key: PersistedDataKey.timestamp) {

            peripheral.update(location: LocationInfo(latitude: latitude, longitude: longitude,
                                                     altitude: deviceStore.read(key: PersistedDataKey.altitude),
                                                     heading: deviceStore.read(key: PersistedDataKey.heading),
                                                     horizontalAccuracy: deviceStore
                .read(key: PersistedDataKey.horizontalAccuracy),
                                                     verticalAccuracy: deviceStore
                .read(key: PersistedDataKey.verticalAccuracy),
                                                     headingAccuracy: deviceStore
                .read(key: PersistedDataKey.headingAccuracy),
                                                     timestamp: date))
        }

        // load sources
        if let supportedSources: StorableArray<Source> = deviceStore.read(key: PersistedDataKey.sources),
           let sources: StorableArray<Source> = presetStore?.read(key: PersistedDataKey.sources) {
            peripheral.update(supportedSources: Set(supportedSources.storableValue))
                .update(sources: Set(sources.storableValue))
        }
    }

    private func applyPresets() {
        if let presetStore = presetStore {
            if let sourcesValues: StorableArray<Source> =
                presetStore.read(key: PersistedDataKey.sources) {
                let newSources = Set(sourcesValues.storableValue)
                if newSources != receivedSources {
                    _ = selectSources(sources: newSources)
                }
                peripheral.update(sources: newSources).notifyUpdated()
            }
        }
    }

    /// Applies sources.
    ///
    /// Gets the last received value if the given one is null;
    /// Sends the obtained value to the drone in case it differs from the last received value;
    /// Updates the component's setting accordingly.
    ///
    /// - Parameter sources: sources to apply
    private func applySources(sources: Set<Source>?) {
        guard let newSources = sources ?? receivedSources else { return }

        if newSources != receivedSources {
            var config = Command.Configure()
            config.config.sources = newSources.compactMap { Arsdk_Navigation_Source(source: $0) }
            _ = sendNavigationCommand(.configure(config))
        }

        peripheral.update(sources: newSources)
    }

    private func save(latitude: Double, longitude: Double, altitude: Double,
                      horizontalAccuracy: Double,
                      verticalAccuracy: Double,
                      timestamp: Date) {

        deviceStore.write(key: PersistedDataKey.latitude, value: latitude)
            .write(key: PersistedDataKey.longitude, value: longitude)
            .write(key: PersistedDataKey.altitude, value: altitude)
            .write(key: PersistedDataKey.horizontalAccuracy, value: horizontalAccuracy)
            .write(key: PersistedDataKey.verticalAccuracy, value: verticalAccuracy)
            .write(key: PersistedDataKey.timestamp, value: timestamp)
            .commit()
    }

    private func save(latitude: Double, longitude: Double, heading: Double, timestamp: Date) {
        deviceStore.write(key: PersistedDataKey.latitude, value: latitude)
            .write(key: PersistedDataKey.longitude, value: longitude)
            .write(key: PersistedDataKey.heading, value: heading)
            .write(key: PersistedDataKey.timestamp, value: timestamp)
            .commit()
    }

    private func save(heading: Double, headingAccuracy: Double) {
        deviceStore.write(key: PersistedDataKey.heading, value: heading)
            .write(key: PersistedDataKey.headingAccuracy, value: headingAccuracy)
            .commit()
    }
}

/// Extension for events processing.
extension AnafiNavigationController: ArsdkNavigationEventDecoderListener {
    func onLocation(_ location: AnafiNavigationController.Event.Location) {
        arsdkNavigationSupported = true

        let hasCurrentLocation = location.hasLatitude && location.hasLongitude
        peripheral.update(hasCurrentLocation: hasCurrentLocation)

        if hasCurrentLocation {
            let currentDate = Date()
            let altitude = location.hasAltitudeAmsl ? location.altitudeAmsl.value : nil
            let heading = location.hasHeading ? location.heading.value.toBoundedDegrees() : nil
            let horizontalAccuracy = location.hasHorizontalAccuracy ? location.horizontalAccuracy.value : nil
            let verticalAccuracy = location.hasVerticalAccuracy ? location.verticalAccuracy.value : nil
            let headingAccuracy = location.hasHeadingAccuracy ? location.headingAccuracy.value.toBoundedDegrees() : nil
            peripheral.update(location: LocationInfo(latitude: location.latitude.value,
                                                     longitude: location.longitude.value,
                                                     altitude: altitude,
                                                     heading: heading,
                                                     horizontalAccuracy: horizontalAccuracy,
                                                     verticalAccuracy: verticalAccuracy,
                                                     headingAccuracy: headingAccuracy,
                                                     timestamp: currentDate))

            save(latitude: location.latitude.value, longitude: location.longitude.value,
                 altitude: location.altitudeAmsl.value,
                 horizontalAccuracy: location.horizontalAccuracy.value,
                 verticalAccuracy: location.verticalAccuracy.value,
                 timestamp: currentDate)

            if let heading = heading, let headingAccuracy = headingAccuracy {
                save(heading: heading, headingAccuracy: headingAccuracy)
            }
        }


        if location.hasGnss && (!location.gnss.hasIsFixed || location.gnss.isFixed.value) {
            peripheral.update(gnssInfo: GnssInfo( satelliteCount: Int(location.gnss.numberOfSatellites)))
        } else {
            peripheral.update(gnssInfo: nil)
        }

        peripheral.update(reliability: Reliability.init(fromArsdk: location.reliability))
            .update(usesMagnetometer: location.locationUsesMagnetometer)
            .notifyUpdated()
    }

    func onState(_ state: AnafiNavigationController.Event.State) {
        if state.hasConfig {
            let sync = receivedSources == nil
            receivedSources = Set(state.config.sources.compactMap { Source(fromArsdk: $0) })
            if sync {
                let sourcesValues: StorableArray<Source>? = presetStore?.read(key: PersistedDataKey.sources)
                let sources = sourcesValues == nil ? nil : Set(sourcesValues!.storableValue)
                applySources(sources: sources)
            } else {
                peripheral.update(sources: receivedSources ?? [])
            }
        }

        if state.hasDefaultCapabilities {
            let supportedSources = Set(state
                .defaultCapabilities.sources.compactMap { Source(fromArsdk: $0) })
            peripheral.update(supportedSources: supportedSources)
            deviceStore.write(key: PersistedDataKey.sources, value: StorableArray(Array(supportedSources))).commit()
        }
        if state.hasGnssSource {
            if let gnssSource = GnssSource(fromArsdk: state.gnssSource.value) {
                peripheral.update(gnssSource: gnssSource)
            }
        }
        peripheral.update(state: state.gsdkState)
            .publish()
    }

    func onRawGnssLocation(_ rawGnssLocation: Arsdk_Navigation_Event.RawGnssLocation) {
        // nothing to do
    }
}

/// Extension for methods to send Navigation commands.
extension AnafiNavigationController: NavigationControlBackend {

    func sendGlobalPose(latitude: Double, longitude: Double, heading: Float) -> Bool {
        var globalPose = Command.SetGlobalPose()
        globalPose.latitude = latitude
        globalPose.longitude = longitude
        globalPose.heading = heading
        return sendNavigationCommand(.setGlobalPose(globalPose))
    }

    func selectSources(sources: Set<Source>) -> Bool {
        presetStore?.write(key: PersistedDataKey.sources, value: StorableArray(Array(sources))).commit()
        if connected {
            applySources(sources: sources)
            return true
        } else {
            peripheral.update(sources: sources).notifyUpdated()
            return false
        }
    }

    /// Sends to the drone a Navigation command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendNavigationCommand(_ command: Command.OneOf_ID) -> Bool {
        if let encoder = Encoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendNavigationCommand(.getState(getState))
    }
}

/// Piloting state Callback implementation.
extension AnafiNavigationController: ArsdkFeatureArdrone3PilotingstateCallback {
    func onGpsLocationChanged(latitude: Double, longitude: Double, altitude: Double,
                              latitudeAccuracy: Int, longitudeAccuracy: Int, altitudeAccuracy: Int) {
        guard !arsdkNavigationSupported else {
            return
        }

        let hasCurrentLocation = latitude != AnafiNavigationController.UnknownCoordinate
        && longitude != AnafiNavigationController.UnknownCoordinate
        peripheral.update(hasCurrentLocation: hasCurrentLocation)

        if hasCurrentLocation {
            let date = Date()
            let horizontalAccuracy = Double(max(latitudeAccuracy, longitudeAccuracy))
            let verticalAccuracy = Double(altitudeAccuracy)
            peripheral.update(location: LocationInfo(latitude: latitude, longitude: longitude, altitude: altitude,
                                                     horizontalAccuracy: horizontalAccuracy,
                                                     verticalAccuracy: verticalAccuracy, timestamp: date))

            save(latitude: latitude, longitude: longitude, altitude: altitude,
                 horizontalAccuracy: horizontalAccuracy,
                 verticalAccuracy: verticalAccuracy, timestamp: date)
        }
        peripheral.notifyUpdated()
    }
}

/// Gps settings state Callback implementation.
extension AnafiNavigationController: ArsdkFeatureArdrone3GpssettingsstateCallback {
    func onGPSFixStateChanged(fixed: UInt) {
        guard !arsdkNavigationSupported else {
            return
        }
        latestGpsFix = fixed == 1
        updateGnssInfo()
    }

    private func updateGnssInfo() {
        let gnssInfo = latestGpsFix ? GnssInfo(satelliteCount: latestSatelliteCount) : nil
        peripheral.update(gnssInfo: gnssInfo).notifyUpdated()
    }
}

/// Gps state Callback implementation.
extension AnafiNavigationController: ArsdkFeatureArdrone3GpsstateCallback {
    func onNumberOfSatelliteChanged(numberofsatellite: UInt) {
        guard !arsdkNavigationSupported else {
            return
        }
        latestSatelliteCount = Int(numberofsatellite)
        updateGnssInfo()
    }
}

/// Backup link decode callback implementation.
extension AnafiNavigationController: ArsdkBackuplinkEventDecoderListener {
    func onTelemetry(_ telemetry: Arsdk_Backuplink_Event.Telemetry) {
        let hasCurrentLocation = telemetry.latitude != AnafiNavigationController.UnknownCoordinate &&
        telemetry.longitude != AnafiNavigationController.UnknownCoordinate

        if hasCurrentLocation {
            let timestamp = Date()
            peripheral.update(location: LocationInfo(latitude: telemetry.latitude,
                                                     longitude: telemetry.longitude,
                                                     heading: Double(telemetry.heading).toBoundedDegrees(),
                                                     timestamp: timestamp))

            save(latitude: telemetry.latitude, longitude: telemetry.longitude,
                 heading: Double(telemetry.heading).toBoundedDegrees(), timestamp: timestamp)
        }

        let gnssInfo = telemetry.locationUsesGnss ? GnssInfo(satelliteCount: nil) : nil
        let reliabilty: Reliability = telemetry.locationIsReliable ? .reliable : .unreliable

        peripheral.update(gnssInfo: gnssInfo)
            .update(hasCurrentLocation: hasCurrentLocation)
            .update(reliability: reliabilty)
            .update(usesMagnetometer: telemetry.locationUsesMagnetometer)
            .notifyUpdated()
    }

    func onMainRadioDisconnecting(_ mainRadioDisconnecting: SwiftProtobuf.Google_Protobuf_Empty) {
        // nothing to do
    }
}

/// Extension that adds conversion to gsdk.
extension AnafiNavigationController.Event.State {
    /// Creates a new `NavigationControlState` from `Arsdk_Navigation_Event.State`.
    var gsdkState: NavigationControlState {
        let frames = availableFrames.frames.compactMap { frame in
            NavigationControlFrame(rawValue: frame.rawValue)
        }
        return NavigationControlState(availableFrames: frames)
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension Arsdk_Navigation_Source {
    init(source: Source) {
        switch source {
        case .gps:
            gps = Google_Protobuf_Empty()
        case .glonass:
            glonass = Google_Protobuf_Empty()
        case .galileo:
            galileo = Google_Protobuf_Empty()
        case .beidou:
            beidou = Google_Protobuf_Empty()
        case .rtk:
            rtk = Google_Protobuf_Empty()
        case .visionMap:
            visionMap = Google_Protobuf_Empty()
        case .odometry:
            odometry = Google_Protobuf_Empty()
        case .barometer:
            barometer = Google_Protobuf_Empty()
        case .magnetometer:
            magnetometer = Google_Protobuf_Empty()
        }
    }
}

/// Extension to make Source storable
extension Source: StorableEnum {
    static var storableMapper = Mapper<Source, String>([
        .gps: "gps",
        .glonass: "glonass",
        .galileo: "galileo",
        .beidou: "beidou",
        .rtk: "rtk",
        .visionMap: "visionMap",
        .odometry: "odometry",
        .barometer: "barometer",
        .magnetometer: "magnetometer"])
}

/// Extension that adds conversion from/to arsdk enum.
extension Source: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Source, Arsdk_Navigation_Source>([
        .gps: Arsdk_Navigation_Source(source: gps),
        .glonass: Arsdk_Navigation_Source(source: glonass),
        .galileo: Arsdk_Navigation_Source(source: galileo),
        .beidou: Arsdk_Navigation_Source(source: beidou),
        .rtk: Arsdk_Navigation_Source(source: rtk),
        .visionMap: Arsdk_Navigation_Source(source: visionMap),
        .odometry: Arsdk_Navigation_Source(source: odometry),
        .barometer: Arsdk_Navigation_Source(source: barometer),
        .magnetometer: Arsdk_Navigation_Source(source: magnetometer)])
}

/// Extension that adds conversion from/to arsdk enum.
extension GnssSource: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<GnssSource, Arsdk_Navigation_GnssSource>([
        .internal: Arsdk_Navigation_GnssSource.gnssInternal,
        .external: Arsdk_Navigation_GnssSource.gnssExternal])
}

/// Extension that adds conversion from/to arsdk enum.
extension Reliability: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<Reliability, Arsdk_Navigation_Reliability>([
        .reliable: .reliable,
        .unreliable: .unreliable
    ])
}
