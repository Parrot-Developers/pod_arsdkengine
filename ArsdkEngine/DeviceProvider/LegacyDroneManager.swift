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

/// Implementation of `RemoteDeviceManager` over `ArsdkFeatureDroneManager` messages.
class LegacyDroneManager: RemoteDeviceManager {

    /// Temporary store for received known providers. Indexed by device uid.
    private var knownProviders: [String: ProviderInfo] = [:]

    /// Constructor.
    ///
    /// - Parameters:
    ///     - deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureDroneManagerUid {
            ArsdkFeatureDroneManager.decode(command, callback: self)
        }
    }

    override func connectDevice(uid: String, technology: DeviceConnectorTechnology,
                                parameters: [DeviceConnectionParameter], wakeIdle: Bool) -> Bool {
        ULog.d(.ctrlTag, "LegacyDroneManager: sending connect command, \(uid)")
        var password = ""
        for parameter in parameters {
            if case let .securityKey(key) = parameter {
                password = key
            }
        }
        _ = sendCommand(ArsdkFeatureDroneManager.connectEncoder(serial: uid, key: password))
        return true
    }

    override func forgetDevice(uid: String) {
        ULog.d(.ctrlTag, "LegacyDroneManager: sending forget command, \(uid)")
        _ = sendCommand(ArsdkFeatureDroneManager.forgetEncoder(serial: uid))
    }
}

/// DroneManager events dispatcher
extension LegacyDroneManager: ArsdkFeatureDroneManagerCallback {
    func onConnectionState(state: ArsdkFeatureDroneManagerConnectionState, serial: String, model: UInt, name: String) {
        let info = ProviderInfo(deviceUid: serial, deviceModelId: Int(model), deviceName: name, technology: .wifi)

        switch state {
        case .idle,
                .searching:
            ULog.d(.ctrlTag, "LegacyDroneManager: onConnectionState: Idle or Searching")
            providerWillDisconnect()
        case .connecting:
            ULog.d(.ctrlTag, "LegacyDroneManager: onConnectionState: Connecting \(serial) \(model) \(name)")
            providerWillConnect(info)
        case .connected:
            ULog.d(.ctrlTag, "LegacyDroneManager: onConnectionState: Connected \(serial) \(model) \(name)")
            providerDidConnect(info)
        case .disconnecting:
            ULog.d(.ctrlTag, "LegacyDroneManager: onConnectionState: Disconnecting \(serial) \(model) \(name)")
            providerWillDisconnect(info.providerId)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            // don't change anything if value is unknown
            ULog.w(.tag, "Unknown connection state, skipping this event.")
            return
        }
    }

    func onAuthenticationFailed(serial: String, model: UInt, name: String) {
        ULog.d(.ctrlTag, "LegacyDroneManager onAuthenticationFailed: \(serial) \(name)")
        let id = ProviderId(deviceUid: serial, technology: .wifi)
        providerAuthenticationDidFail(id, cause: .badPassword)
    }

    func onConnectionRefused(serial: String, model: UInt, name: String) {
        ULog.d(.ctrlTag, "LegacyDroneManager onConnectionRefused: \(serial) \(name)")
        let id = ProviderId(deviceUid: serial, technology: .wifi)
        providerConnectionWasRefused(id)
    }

    func onKnownDroneItem(serial: String, model: UInt, name: String, security: ArsdkFeatureDroneManagerSecurity,
                          hasSavedKey: UInt, listFlagsBitField: UInt) {
        ULog.d(.ctrlTag, "LegacyDroneManager: onKnownDroneItem \(serial) \(model) " +
               "\(name) security = \(security.rawValue) listFlags = \(listFlagsBitField)")
        if ArsdkFeatureGenericListFlagsBitField.isSet(.empty, inBitField: listFlagsBitField) {
            // remove all
            knownProviders.removeAll()
            knownProvidersDidChange(Array(knownProviders.values))
        } else {
            // first, remove all
            if ArsdkFeatureGenericListFlagsBitField.isSet(.first, inBitField: listFlagsBitField) {
                knownProviders.removeAll()
            }
            if ArsdkFeatureGenericListFlagsBitField.isSet(.remove, inBitField: listFlagsBitField) {
                // remove
                knownProviders[serial] = nil
            } else {
                // add
                let info = ProviderInfo(deviceUid: serial, deviceModelId: Int(model), deviceName: name,
                                        technology: .wifi)
                knownProviders[serial] = info
            }
            // last
            if ArsdkFeatureGenericListFlagsBitField.isSet(.last, inBitField: listFlagsBitField) {
                knownProvidersDidChange(Array(knownProviders.values))
            }
        }
    }
}
