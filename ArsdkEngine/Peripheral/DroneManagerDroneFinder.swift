// Copyright (C) 2019 Parrot Drones SAS
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

/// DroneFinder component controller
class DroneManagerDroneFinder: DeviceComponentController {
    /// Drone finder component
    private var droneFinder: DroneFinderCore!

    /// Device manager to use to connect to discovered drones.
    private var deviceManager: RemoteDeviceManager

    /// Drones seen during discovery, by drone uid.
    private var drones = [String: DiscoveredDroneCore]()

    /// Known drones of the remote control. Indexed by drone uid.
    private var knownDrones = [String: KnownDroneCore]()

    /// Constructor
    ///
    /// - Parameters:
    ///    - deviceController: device controller owning this component controller (weak)
    ///    - deviceManager: device manager to use to connect to discovered drones
    init(deviceController: DeviceController, deviceManager: RemoteDeviceManager) {
        self.deviceManager = deviceManager
        super.init(deviceController: deviceController)
        droneFinder = DroneFinderCore(store: deviceController.device.peripheralStore, backend: self)
    }

    /// Drone is connected
    override func didConnect() {
        droneFinder.publish()
    }

    /// Drone is disconnected
    override func didDisconnect() {
        droneFinder.unpublish()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureDroneManagerUid {
            ArsdkFeatureDroneManager.decode(command, callback: self)
        }
    }

    private func notifyDiscoveredDronesDidChange() {
        let discoveredDrones = drones.values.sorted { first, second in
            if first.rssi > second.rssi {
                return true
            } else if first.rssi < second.rssi {
                return false
            } else {
                return first.name.compare(second.name) == ComparisonResult.orderedAscending
            }
        }
        droneFinder.update(discoveredDrones: discoveredDrones).update(state: .idle).notifyUpdated()
    }

    private func notifyKnownDronesDidChange() {
        let knownDrones = knownDrones.values.sorted { first, second in
            return first.name.compare(second.name) == ComparisonResult.orderedAscending
        }
        droneFinder.update(knownDrones: knownDrones).notifyUpdated()
    }
}

/// DroneFinder backend implementation
extension DroneManagerDroneFinder: DroneFinderBackend {

    func discoverDrones(useBackupRadio: Bool) {
        ULog.d(.ctrlTag, "DroneManagerDroneFinder: sending DiscoverDrones command")
        _ = sendCommand(ArsdkFeatureDroneManager.discoverDronesEncoder())
        droneFinder.update(state: .scanning).notifyUpdated()
    }

    /// Stop discovery is not available with this implementation
    func stopDiscovery() -> Bool {
        return false
    }

    func connectDrone(uid: String, parameters: [DeviceConnectionParameter], wakeIdle: Bool) -> Bool {
        if let drone = drones[uid] {
            return deviceManager.connectDiscoveredProvider(deviceUid: drone.uid,
                                                           deviceModel: .drone(drone.model),
                                                           deviceName: drone.name,
                                                           technology: .wifi,
                                                           parameters: parameters,
                                                           wakeIdle: wakeIdle)
        }
        return false
    }

    /// Connecting to a known drone is not available with this implementation
    func connectKnownDrone(uid: String) -> Bool {
        return false
    }
}

/// DroneManager events dispatcher
extension DroneManagerDroneFinder: ArsdkFeatureDroneManagerCallback {

    func onDroneListItem(serial: String, model: UInt, name: String, connectionOrder: UInt, active: UInt,
                         visibleBitField: UInt, security: ArsdkFeatureDroneManagerSecurity, hasSavedKey: UInt,
                         rssi: Int, listFlagsBitField: UInt) {
        ULog.d(.ctrlTag, "DroneManagerDroneFinder: onDroneListItem: \(serial) \(name)" +
               " \(connectionOrder)")
        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            // remove all
            drones.removeAll()
            notifyDiscoveredDronesDidChange()
            // notify
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                // remove
                drones[serial] = nil
            } else {
                // first, remove all
                if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                    drones.removeAll()
                }
                // add
                if case .drone(let droneModel)? = DeviceModel.from(internalId: Int(model)), visibleBitField != 0 {
                    func computeSecurity(visibleBitField: UInt,
                                         security: ArsdkFeatureDroneManagerSecurity, hasSavedKey: UInt)
                    -> ConnectionSecurity {
                        if ArsdkFeatureDroneManagerVisibleStateBitField.isSet(.wifiVisible,
                                                                              inBitField: visibleBitField) {
                            switch security {
                            case .wpa2:
                                return (hasSavedKey != 0) ? .savedPassword : .password
                            case .none:
                                return .none
                            case .sdkCoreUnknown:
                                fallthrough
                            @unknown default:
                                // don't change anything if value is unknown
                                ULog.w(.tag, "Unknown security, setting it to none.")
                                return .none
                            }
                        } else {
                            // if the drone is not visible in wifi, force the security to none.
                            return .none
                        }
                    }

                    drones[serial] = DiscoveredDroneCore(
                        uid: serial, model: droneModel, name: name, known: connectionOrder != 0, rssi: rssi,
                        connectionSecurity: computeSecurity(visibleBitField: visibleBitField,
                                                            security: security, hasSavedKey: hasSavedKey),
                        wifiVisibility: ArsdkFeatureDroneManagerVisibleStateBitField.isSet(
                            .wifiVisible, inBitField: visibleBitField),
                        cellularOnLine: ArsdkFeatureDroneManagerVisibleStateBitField.isSet(
                            .cellularOnline, inBitField: visibleBitField), backupLinkVisibility: .invisible)

                } else {
                    ULog.w(.ctrlTag, "Ignoring onDroneListItem for model \(model)")
                }
            }
            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                // notify
                notifyDiscoveredDronesDidChange()
            }
        }
    }

    func onKnownDroneItem(serial: String, model: UInt, name: String,
                          security: ArsdkFeatureDroneManagerSecurity,
                          hasSavedKey: UInt, listFlagsBitField: UInt) {

        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            knownDrones.removeAll()
            notifyKnownDronesDidChange()
        } else if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
            knownDrones[serial] = nil
        } else {
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                knownDrones.removeAll()
            }
            if case .drone(let droneModel)? = DeviceModel.from(internalId: Int(model)) {
                knownDrones[serial] = KnownDroneCore(uid: serial, model: droneModel,
                                                     name: name,
                                                     connectionTypes: Set([.wifi]))
            }
        }

        if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
            notifyKnownDronesDidChange()
        }
    }
}
