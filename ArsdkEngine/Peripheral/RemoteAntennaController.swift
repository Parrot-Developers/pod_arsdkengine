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

/// Remote antenna component controller for SkyController UA remote controls.
class RemoteAntennaController: DeviceComponentController {

    /// Remote antenna component
    private var remoteAntenna: RemoteAntennaCore!

    /// Decoder for remote antenna controller events.
    private var arsdkDecoder: ArsdkRemoteantennaEventDecoder!

    /// Current remote antenna version
    private var firmwareIdentifier: FirmwareIdentifier?

    /// Blacklisted firmware version store
    private let blacklistStore: BlacklistedVersionStoreCore?

    /// Monitors changes on the blacklist store
    private var blacklistStoreMonitor: MonitorCore?

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        blacklistStore = deviceController.engine.utilities.getUtility(Utilities.blacklistedVersionStore)
        super.init(deviceController: deviceController)
        remoteAntenna = RemoteAntennaCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = ArsdkRemoteantennaEventDecoder(listener: self)
    }

    override func willConnect() {
        _ = sendGetStateCommand()
    }

    override func didConnect() {
        monitorBlacklistStore()
    }

    override func didDisconnect() {
        remoteAntenna.cancelSettingsRollback()
            .update(state: nil)
            .update(batteryCharge: nil)
            .update(location: nil)
            .update(isLocationRequired: nil)
            .update(heading: nil)
            .update(motorizedSupport: nil)
            .update(motorizedSupportAlarms: [])

        blacklistStoreMonitor?.stop()

        remoteAntenna.unpublish()
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }
}

/// Remote antenna backend implementation.
extension RemoteAntennaController: RemoteAntennaBackend {

    func set(enabled: Bool) -> Bool {
        var sent = false
        if connected {
            sent = sendRemoteAntennaCommand(enabled ? .enable(Arsdk_Remoteantenna_Command.Enable())
                                            : .disable(Arsdk_Remoteantenna_Command.Disable()))
        }
        return sent
    }

    func set(location: CLLocationCoordinate2D) -> Bool {
        var sent = false
        if connected {
            var coordinate = Arsdk_Remoteantenna_GpsCoordinates()
            coordinate.latitude = location.latitude
            coordinate.longitude = location.longitude
            sent = sendRemoteAntennaCommand(.setAntennaCoordinates(coordinate))
        }
        return sent
    }

    func connect(serialNumber: String) -> Bool {
        var sent = false
        if connected {
            var command = Arsdk_Remoteantenna_Command.CloudConnect()
            command.serial = serialNumber
            sent = sendRemoteAntennaCommand(.cloudConnect(command))
        }
        return sent
    }

    func disconnect() -> Bool {
        var sent = false
        if connected {
            sent = sendRemoteAntennaCommand(.cloudDisconnect(Arsdk_Remoteantenna_Command.CloudDisconnect()))
        }
        return sent
    }
}

/// Extension for methods to send remote antenna commands.
extension RemoteAntennaController {

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var getState = Arsdk_Remoteantenna_Command.GetState()
        getState.includeDefaultCapabilities = true
        return sendRemoteAntennaCommand(.getState(getState))
    }

    /// Sends to the remote control a remote antenna command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendRemoteAntennaCommand(_ command: Arsdk_Remoteantenna_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkRemoteantennaCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension for events processing.
extension RemoteAntennaController: ArsdkRemoteantennaEventDecoderListener {

    func onState(_ state: Arsdk_Remoteantenna_Event.State) {
        // enabled
        if state.hasEnabled {
            remoteAntenna.update(enabled: state.enabled.value)
        }

        // state
        if state.hasAntennaStatus {
            remoteAntenna.update(state: state.antennaStatus.value.gsdk(isCloud: state.useCloudAntenna))
        }

        if case .connected = remoteAntenna.state {
            // battery charge
            if state.hasAntennaBatteryLevel {
                remoteAntenna.update(batteryCharge: Int(state.antennaBatteryLevel.value))
            }

            if state.hasChargingState {
                remoteAntenna.update(batteryCharging: state.chargingState.value  == .charging)
            }

            if state.hasChargerPlugged {
                remoteAntenna.update(chargerPlugged: state.chargerPlugged.value)
            }

            if state.hasAvailableBandwidth {
                remoteAntenna.update(availableBandwidth: state.availableBandwidth.value)
            }

            if state.hasDeviceInfo {
                if let rcModel = DeviceModel.from(internalId: Int(state.deviceInfo.model)) {
                    if let firmwareVersion = FirmwareVersion.parse(versionStr: state.deviceInfo.firmwareVersion) {
                        firmwareIdentifier = FirmwareIdentifier(deviceModel: rcModel, version: firmwareVersion)
                    }
                    remoteAntenna.update(systemInfo: RemoteAntennaSystemInfo(
                        model: rcModel,
                        serialNumber: state.deviceInfo.serial,
                        firmwareVersion: state.deviceInfo.firmwareVersion,
                        isFirmwareBlacklisted: isFirmwareBlacklisted(),
                        productVariant: RemoteAntennaProductVariant(fromArsdk:
                                                                        state.deviceInfo.productVariant) ?? .standard))
                }

                remoteAntenna.update(isLocationRequired: state.deviceInfo.needsGpsCoordinates)
            }

            if state.hasAntennaCoordinates {
                remoteAntenna.update(location: CLLocationCoordinate2D(
                    latitude: state.antennaCoordinates.latitude,
                    longitude: state.antennaCoordinates.longitude))
            }

            switch state.motorizedSupportStatus {
            case .disconnected:
                remoteAntenna.update(motorizedSupportAlarms: []).update(motorizedSupport: nil)

            case .connected:
                remoteAntenna.update(motorizedSupport: MotorizedSupport(
                    serialNumber: state.connected.serial,
                    alarms: Set(state.connected.alarms.compactMap { MotorizedSupportAlarm(fromArsdk: $0) })
                ))

            case .none:
                break
            }
        } else {
            remoteAntenna.update(batteryCharge: nil)
                .update(batteryCharging: nil)
                .update(chargerPlugged: nil)
                .update(availableBandwidth: nil)
                .update(systemInfo: nil)
                .update(location: nil)
                .update(isLocationRequired: nil)
                .update(motorizedSupport: nil)
                .update(motorizedSupportAlarms: [])
        }
        remoteAntenna.publish()
    }

    /// Checks whether the current firmware version is blacklisted.
    ///
    /// - Note: this function won't call `notifyUpdated()` on the systemInfo component.
    ///
    /// - Returns: `true` if the firmware is blacklisted
    private func isFirmwareBlacklisted() -> Bool {
        if let firmwareIdentifier,
            let blacklisted = blacklistStore?.isBlacklisted(firmwareIdentifier: firmwareIdentifier) {
                return blacklisted
        }
        return false
    }

    /// Starts monitoring the blacklisted firmware version store
    ///
    /// - Note: this function won't call `notifyUpdated()` on the systemInfo component.
    private func monitorBlacklistStore() {
        blacklistStoreMonitor = blacklistStore?.startMonitoring { [weak self] in
            guard let self = self, var systemInfo = remoteAntenna.systemInfo else { return }
            systemInfo.isFirmwareBlacklisted = self.isFirmwareBlacklisted()
            remoteAntenna.update(systemInfo: systemInfo).notifyUpdated()
        }
    }

    func onDiscoveredCloudAntennas(_ discoveredCloudAntennas: Arsdk_Remoteantenna_Event.DiscoveredCloudAntennas) {
        let serials = discoveredCloudAntennas.antennas.compactMap { $0.hasInfo ? $0.info.serial : nil }
        remoteAntenna.update(discoveredAntennas: serials).notifyUpdated()
    }

    func onHeading(_ heading: Arsdk_Remoteantenna_Event.Heading) {
        remoteAntenna.update(heading: Double(heading.value).toBoundedDegrees()).notifyUpdated()
    }
}

extension Arsdk_Remoteantenna_AntennaStatus {
    func gsdk(isCloud: Bool) -> RemoteAntennaState? {
        switch self {
        case .inactive: return .disabled
        case .activating: return .searching
        case .connecting: return .connecting(isCloud: isCloud)
        case .active: return .connected(isCloud: isCloud)
        case .UNRECOGNIZED(_):
            return nil
        }
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension MotorizedSupportAlarm: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<MotorizedSupportAlarm, Arsdk_Remoteantenna_MotorizedSupportAlarm>([
        .motorStall: .motorStall,
        .tooMuchAngle: .tooMuchAngle,
        .wrongUsbPort: .wrongUsbPort
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension RemoteAntennaProductVariant: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<RemoteAntennaProductVariant, Arsdk_Remoteantenna_ProductVariant>([
        .standard: .standard,
        .ranger: .ranger
    ])
}
