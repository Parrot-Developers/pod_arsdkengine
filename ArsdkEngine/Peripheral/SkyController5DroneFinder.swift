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

/// DroneFinder component controller for SkyController5.
class SkyController5DroneFinder: DeviceComponentController {
    /// Drone finder component.
    private var droneFinder: DroneFinderCore!

    /// Decoder for device manager events.
    private var arsdkDecoder: ArsdkDevicemanagerEventDecoder!

    /// Device manager to use to connect to discovered drones.
    private var deviceManager: RemoteDeviceManager

    /// Drones seen during discovery.
    private var drones = [DiscoveredDroneCore]()

    /// Known drones of the remote control. Indexed by drone uid.
    private var knownDrones = [KnownDroneCore]()

    /// Whether the remote control is currently scanning idle devices or not.
    private var scanningIdleDevices = false

    /// Constructor.
    ///
    /// - Parameters:
    ///    - deviceController: device controller owning this component controller (weak)
    ///    - deviceManager: device manager to use to connect to discovered drones
    init(deviceController: DeviceController, deviceManager: RemoteDeviceManager) {
        self.deviceManager = deviceManager
        super.init(deviceController: deviceController)
        droneFinder = DroneFinderCore(store: deviceController.device.peripheralStore, backend: self)
        arsdkDecoder = ArsdkDevicemanagerEventDecoder(listener: self)
    }

    /// Drone is connected
    override func didConnect() {
        droneFinder.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        droneFinder.update(discoveryStatus: nil)
        droneFinder.update(state: .idle)
        scanningIdleDevices = false
        droneFinder.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkDecoder.decode(command)
    }

    private func notifyDiscoveredDronesDidChange() {
        droneFinder.update(discoveredDrones: drones)
        if !scanningIdleDevices {
            droneFinder.update(state: .idle)
        }
        droneFinder.notifyUpdated()
    }
}

/// DroneFinder backend implementation.
extension SkyController5DroneFinder: DroneFinderBackend {

    func discoverDrones(useBackupRadio: Bool) {
        ULog.d(.ctrlTag, "SkyController5DroneFinder: sending DiscoverDrones command")
        if sendDiscoverDevicesCommand(useBackupRadio: useBackupRadio) {
            droneFinder.update(state: .scanning).notifyUpdated()
        }
    }

    func stopDiscovery() -> Bool {
        if sendStopDiscoveryCommand() {
            droneFinder.update(state: .idle)
            return true
        } else {
            return false
        }
    }

    func connectDrone(uid: String, parameters: [DeviceConnectionParameter], wakeIdle: Bool) -> Bool {
        if let drone = drones.first(where: { $0.uid == uid }) {
            return deviceManager.connectDiscoveredProvider(deviceUid: drone.uid,
                                                           deviceModel: .drone(drone.model),
                                                           deviceName: drone.name,
                                                           technology: .wifi,
                                                           parameters: parameters,
                                                           wakeIdle: wakeIdle)
        }
        return false
    }

    func connectKnownDrone(uid: String) -> Bool {
        // Connecting to a knownDrone is only available for MARS.
        guard let knownDrone = knownDrones.first(where: { $0.uid == uid }),
              knownDrone.connectionTypes.contains(.mars) else { return false }

        var connect = Arsdk_Devicemanager_Command.ConnectDevice()
        connect.mars = Arsdk_Devicemanager_Command.ConnectDevice.Mars()
        connect.uid = uid
        connect.wakeIdle = false
        return sendCommand(.connectDevice(connect))
    }
}

/// Extension for methods to send DeviceManager commands.
extension SkyController5DroneFinder {
    /// Sends to the device a DeviceManager command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendCommand(_ command: Arsdk_Devicemanager_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkDevicemanagerCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }

    /// Sends command to discover devices.
    ///
    /// - Parameter useBackupRadio: whether to use backup radio or not
    /// - Returns: `true` if the command has been sent
    func sendDiscoverDevicesCommand(useBackupRadio: Bool) -> Bool {
        var discoverDevices = Arsdk_Devicemanager_Command.DiscoverDevices()
        discoverDevices.useBackupRadio = useBackupRadio
        return sendCommand(.discoverDevices(discoverDevices))
    }

    func sendStopDiscoveryCommand() -> Bool {
        return sendCommand(.stopDiscovery(Arsdk_Devicemanager_Command.StopDiscovery()))
    }
}

/// Extension for events processing.
extension SkyController5DroneFinder: ArsdkDevicemanagerEventDecoderListener {
    func onDiscoveredDevices(_ discoveredDevices: Arsdk_Devicemanager_Event.DiscoveredDevices) {
        drones = discoveredDevices.devices.compactMap { $0.gsdk }
        if let discoveryStatus = DiscoveryStatus(fromArsdk: discoveredDevices.status) {
            droneFinder.update(discoveryStatus: discoveryStatus)
        }
        notifyDiscoveredDronesDidChange()
    }

    func onState(_ state: Arsdk_Devicemanager_Event.State) {
        if state.hasDefaultCapabilities {
            droneFinder.update(connectionTypes: Set(state.defaultCapabilities.availableTransports
                .compactMap { $0.gsdkConnectionType }))
        }
        if state.hasKnownDevices {
            knownDrones = state.knownDevices.devices.compactMap { $0.gsdk }
            droneFinder.update(knownDrones: knownDrones)
        }

        switch state.connectionState {
        case .searching(let searching):
            droneFinder.update(state: .scanning)
            scanningIdleDevices = searching.scanningIdleDevices
        case .none:
            break
        default:
            droneFinder.update(state: .idle)
        }
        droneFinder.notifyUpdated()
    }

    func onConnectionFailure(_ connectionFailure: Arsdk_Devicemanager_Event.ConnectionFailure) {
        // ignored
    }

    func onPairingDone(_ pairingDone: Arsdk_Devicemanager_Event.PairingDone) {
        // ignored
    }

    func onPairingFailed(_ pairingFailed: Arsdk_Devicemanager_Event.PairingFailed) {
        // ignored
    }
}

/// Extension that adds conversion to `DiscoveredDroneCore`.
extension Arsdk_Devicemanager_DiscoveredDevice {
    var gsdk: DiscoveredDroneCore? {
        guard hasInfo,
              case .drone(let droneModel)? = DeviceModel.from(internalId: Int(info.model)),
              GroundSdkConfig.sharedInstance.supportedDevices.contains(.drone(droneModel)) else {
            return nil
        }
        var wifiVisibile = false
        var rssi = 0
        var security = ConnectionSecurity.none
        if hasWifiVisibility {
            wifiVisibile = true
            rssi = Int(wifiVisibility.rssi)
            if wifiVisibility.hasTransportInfo,
               wifiVisibility.transportInfo.security == .wpa2 {
                security = wifiVisibility.transportInfo.savedKey ? .savedPassword : .password
            }
        }
        var droneBackupLinkVisibility: DroneBackupLinkVisibility = .invisible
        if hasBackupLinkVisibility {
            droneBackupLinkVisibility = backupLinkVisibility.droneStarted == true ? .visibleAndStarted : .visibleAndIdle
        }

        return DiscoveredDroneCore(
            uid: info.uid, model: droneModel, name: info.networkID, known: known, rssi: rssi,
            connectionSecurity: security, wifiVisibility: wifiVisibile,
            cellularOnLine: hasCellularVisibility, backupLinkVisibility: droneBackupLinkVisibility)
    }
}

/// Extension that adds conversion to `KnownDroneCore`.
extension Arsdk_Devicemanager_KnownDevice {
    fileprivate var gsdk: KnownDroneCore? {
        guard hasInfo,
              case .drone(let droneModel)? = DeviceModel.from(internalId: Int(info.model)),
              GroundSdkConfig.sharedInstance.supportedDevices.contains(.drone(droneModel)) else {
            return nil
        }
        var types = Set<DroneConnectionType>()
        if hasWifi {
            types.insert(.wifi)
        }
        if hasCellular {
            types.insert(.cellular)
        }
        if hasMicrohard {
            types.insert(.microhard)
        }
        if hasMars {
            types.insert(.mars)
        }
        if hasBackupLink {
            types.insert(.backupLink)
        }

        return KnownDroneCore(
            uid: info.uid, model: droneModel, name: info.networkID, connectionTypes: types)
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension DiscoveryStatus: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<DiscoveryStatus, Arsdk_Devicemanager_DiscoveryStatus>([
        .success: .success,
        .errorRadioNotReady: .errorRadioNotReady,
        .errorNoDiscoverableDrone: .errorNoDiscoverableDrone])
}
