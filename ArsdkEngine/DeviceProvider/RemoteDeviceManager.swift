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

/// Delegate for controllers (such as remote control devices) that allows to list and connect to other remote devices.
class RemoteDeviceManager: DeviceComponentController {

    /// A unique identifier for a remote device.
    struct ProviderId: Hashable {

        /// Unique identifier of the provided device.
        let deviceUid: String

        /// Technology used by the provider.
        let technology: DeviceConnectorTechnology
    }

    /// Raw information about a remote device.
    struct ProviderInfo {

        /// Unique identifier of the provided device.
        let deviceUid: String

        /// Raw identifier of the provided device model.
        let deviceModelId: Int

        /// Optional name of the provided device.
        let deviceName: String?

        /// Technology used by the provider.
        let technology: DeviceConnectorTechnology

        /// Provider identifier.
        var providerId: ProviderId { ProviderId(deviceUid: deviceUid, technology: technology) }
    }

    /// A `DeviceProvider` that provides connection to a remote device using a given technology.
    private class Provider: DeviceProvider {

        /// Device manager managing this provider.
        private weak var remoteDeviceManager: RemoteDeviceManager?

        /// Unique identifier of the remote device.
        let deviceUid: String

        /// Model of the remote device.
        private let deviceModel: DeviceModel

        /// Optional name of the remote device.
        private let deviceName: String?

        /// Technology to use to connect with the remote device.
        private let technology: DeviceConnectorTechnology

        /// Engine device controller that represents the device.
        var controller: DeviceController?

        /// Backend for the represented device controller.
        var backend: DeviceControllerBackend? {
            remoteDeviceManager?.deviceController.backend
        }

        /// Marks this provider as known to the managing device.
        var known: Bool {
            get {
                remoteDeviceManager?.knownProviders.contains(self) == true
            }
            set(known) {
                if known {
                    remoteDeviceManager?.knownProviders.insert(self)
                } else {
                    remoteDeviceManager?.knownProviders.remove(self)
                    if self !== remoteDeviceManager?.activeProvider
                        && self !== remoteDeviceManager?.authFailedProvider {
                        unregister()
                    }
                }
            }
        }

        /// Marks this provider active (connected).
        ///
        /// Only one provider can be active at a time. Any previously active provider will be disconnected beforehand.
        ///
        /// Marking a provider active resets the latest `authFailedProvider` undergo authentication failure.
        var active: Bool {
            get {
                self === remoteDeviceManager?.activeProvider
            }
            set(active) {
                guard self.active != active,
                      let remoteDeviceManager = remoteDeviceManager else {
                    return
                }

                if let activeProvider = remoteDeviceManager.activeProvider {
                    activeProvider.controller?.linkDidDisconnect(removing: false)

                    if !remoteDeviceManager.knownProviders.contains(activeProvider)
                        && activeProvider !== remoteDeviceManager.authFailedProvider {
                        activeProvider.unregister()
                    }
                }

                if active {
                    remoteDeviceManager.activeProvider = self
                    remoteDeviceManager.authFailedProvider = nil
                } else {
                    remoteDeviceManager.activeProvider = nil
                }

                remoteDeviceManager.deviceController.dataSyncAllowanceMightHaveChanged()
            }
        }

        /// Marks an authentication failure for this provider.
        ///
        /// Only the active provider can be marked so.
        ///
        /// - Note: Authentication failure marker is reset as soon as a provider becomes active.
        var authenticationFailed: Bool {
            get {
                self === remoteDeviceManager?.authFailedProvider
            }
            set(failed) {
                guard self.authenticationFailed != failed,
                      !failed || active,
                      let remoteDeviceManager = remoteDeviceManager else {
                    return
                }

                if let authFailedProvider = remoteDeviceManager.authFailedProvider,
                   !remoteDeviceManager.knownProviders.contains(authFailedProvider),
                   authFailedProvider !== remoteDeviceManager.activeProvider {
                    authFailedProvider.unregister()
                }

                remoteDeviceManager.authFailedProvider = failed ? self : nil
            }
        }

        /// Constructor.
        ///
        /// - Parameters:
        ///   - remoteDeviceManager: device manager managing the provider
        ///   - deviceUid: unique identifier of the remote device
        ///   - deviceModel: model of the remote device
        ///   - deviceName: optional name of the remote device
        ///   - technology: technology to use to connect with the remote device
        init(remoteDeviceManager: RemoteDeviceManager,
             deviceUid: String, deviceModel: DeviceModel, deviceName: String?,
             technology: DeviceConnectorTechnology) {
            self.remoteDeviceManager = remoteDeviceManager
            self.deviceUid = deviceUid
            self.deviceModel = deviceModel
            self.deviceName = deviceName
            self.technology = technology
            super.init(connector: RemoteControlDeviceConnectorCore(
                uid: remoteDeviceManager.deviceController.device.uid))
            self.parent = remoteDeviceManager.deviceController.activeProvider

            controller = remoteDeviceManager.deviceController.engine
                .getOrCreateDeviceController(uid: deviceUid, model: deviceModel, name: deviceName ?? "")
            controller?.addProvider(self)
        }

        /// Detaches this provider from the represented controller and removes it from the store.
        func unregister() {
            controller?.removeProvider(self)
            controller = nil
            remoteDeviceManager?.providersStore.removeValue(
                forKey: RemoteDeviceManager.ProviderId(deviceUid: deviceUid, technology: technology))
        }

        override func connect(deviceController: DeviceController, parameters: [DeviceConnectionParameter],
                              wakeIdle: Bool) -> Bool {
            if remoteDeviceManager?.connectDevice(uid: deviceUid,
                                                  technology: technology,
                                                  parameters: parameters,
                                                  wakeIdle: wakeIdle) == true {
                // Set this provider active, so that it will be properly be disconnected upon new connection
                active = true
                return true
            }
            return false
        }

        override func disconnect(deviceController: DeviceController) -> Bool { false }

        override func forget(deviceController: DeviceController) {
            remoteDeviceManager?.forgetDevice(uid: deviceUid)
            authenticationFailed = false
            active = false
            known = false
            unregister()
        }

        override func dataSyncAllowanceMightHaveChanged(deviceController: DeviceController) {
            remoteDeviceManager?.deviceController.dataSyncAllowanceMightHaveChanged()
        }
    }

    /// Indexes all providers by their unique identifier.
    private var providersStore: [ProviderId: Provider] = [:]

    /// References all providers that are known by the managing device.
    private var knownProviders: Set<Provider> = []

    /// References the currently active (connected) provider.
    private var activeProvider: Provider?

    /// References the latest provider whose connection aborted due to authentication failure.
    private var authFailedProvider: Provider?

    /// Constructor.
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        if let provider = activeProvider {
            provider.controller?.didReceiveCommand(command)
        }
    }

    override func didDisconnect() {
        clearProviders()
    }

    /// Retrieves the provider identified by the given information or creates it in case it does not exist.
    ///
    /// - Parameter info: provider information
    /// - Returns: retrieved or created provider instance, or `nil` if it is impossible to create a
    /// provider from specified info (mainly in case the device model is unknown or not supported
    /// in current GroundSdk configuration.
    private func getOrCreateProvider(_ info: ProviderInfo) -> Provider? {
        if let model = DeviceModel.from(internalId: info.deviceModelId),
           GroundSdkConfig.sharedInstance.supportedDevices.contains(model) {
            var provider = providersStore[info.providerId]
            if provider == nil {
                provider = Provider(remoteDeviceManager: self,
                                    deviceUid: info.deviceUid,
                                    deviceModel: model,
                                    deviceName: info.deviceName,
                                    technology: info.technology)
                providersStore[info.providerId] = provider
            }
            return provider
        }
        return nil
    }

    /// Gets all stored providers except those with specified identifiers.
    ///
    /// - Parameter ids: identifiers of poviders to exclude
    /// - Returns: stored providers except those with specified identifiers
    private func providersMinus(ids: [ProviderId]) -> [Provider] {
        Array(providersStore.filter { !ids.contains($0.key) }.values)
    }

    /// Clears the providers store.
    ///
    /// All providers are detached from their controller and removed.
    func clearProviders() {
        authFailedProvider = nil
        activeProvider = nil
        knownProviders.removeAll()
        providersStore.forEach { $1.unregister() }
        providersStore.removeAll()
    }

    /// Connects to a device using a discovered provider.
    ///
    /// This function is used to connect  a device scanned by discovery. As such a device may not be
    /// known to the device manager or registered in arsdk engine, this function will first register
    /// a `DeviceProvider` for the device using specified information, then request connection.
    ///
    /// - Parameters:
    ///   - deviceUid: unique identifier of the device to connect
    ///   - deviceModel: model of the device to connect
    ///   - deviceName: optional name of the device to connect
    ///   - technology: technology to use for connection
    ///   - parameters: optional custom parameters to use for connection
    ///   - wakeIdle: `true` to wake up the drone if it's in idle state
    /// - Returns: `true` if connection to the device was successfully initiated
    func connectDiscoveredProvider(deviceUid: String, deviceModel: DeviceModel, deviceName: String? = nil,
                                   technology: DeviceConnectorTechnology,
                                   parameters: [DeviceConnectionParameter], wakeIdle: Bool) -> Bool {
        if let provider = getOrCreateProvider(ProviderInfo(deviceUid: deviceUid,
                                                           deviceModelId: deviceModel.internalId,
                                                           deviceName: deviceName, technology: technology)) {
            return provider.controller?.doConnect(provider: provider,
                                                  parameters: parameters,
                                                  cause: .userRequest, wakeIdle: wakeIdle) ?? false
        }
        return false
    }

    /// Connects to a device.
    ///
    /// - Parameters:
    ///   - uid: unique identifier of the device to connect
    ///   - technology: technology to use for connection
    ///   - parameters: optional custom parameters to use for connection
    ///   - wakeIdle: `true` to wake up the drone if it's in idle state
    /// - Returns: `true` if the request has been process
    /// - Note: Subclasses should override this function.
    func connectDevice(uid: String, technology: DeviceConnectorTechnology,
                       parameters: [DeviceConnectionParameter], wakeIdle: Bool) -> Bool {
        return false
    }

    /// Forgets a device.
    ///
    /// - Parameter uid: unique identifier of the device to forget
    /// - Note: Subclasses should override this function.
    func forgetDevice(uid: String) { }

    /// Notifies that a device is connecting.
    ///
    /// - Parameter info: device and technology information
    /// - Parameter backupLink: `true` if backup link is active
    func providerWillConnect(_ info: ProviderInfo, backupLink: Bool = false) {
        if let provider = getOrCreateProvider(info) {
            // if another device is active and not disconnected or the same device has its transport link connected
            if let activeProvider = activeProvider,
               (activeProvider.deviceUid != info.deviceUid
                && activeProvider.controller?.connectionSession.state != .disconnected)
                || (activeProvider.deviceUid == info.deviceUid
                    && activeProvider.controller?.connectionSession.state != .disconnected
                    && activeProvider.controller?.connectionSession.state != .connecting) {
                // force a link disconnection
                provider.controller?.linkDidDisconnect(removing: false)
            }

            provider.active = true
            provider.controller?.linkWillConnect(provider: provider, backupLink: backupLink)
        }
    }

    /// Notifies that a device is connected.
    ///
    /// - Parameter info: device and technology information
    /// - Parameter backupLink: `true` if backup link is active
    func providerDidConnect(_ info: ProviderInfo, backupLink: Bool = false) {
        if let provider = getOrCreateProvider(info),
           let backend = provider.backend {
            provider.active = true
            if backupLink {
                provider.controller?.backupLinkDidActivate(provider: provider, backend: backend)
            } else {
                provider.controller?.linkDidConnect(provider: provider, backend: backend)
            }
        }
    }

    /// Notifies that a device connection aborted due to authentication failure.
    ///
    /// - Parameter id: device and technology identifier
    /// - Parameter cause: connection failure cause
    func providerAuthenticationDidFail(_ id: ProviderId, cause: DeviceState.ConnectionStateCause) {
        if let provider = providersStore[id] {
            provider.authenticationFailed = true
            provider.controller?.linkDidCancelConnect(cause: cause, removing: false)
        }
    }

    /// Notifies that connection was refused by remote device.
    ///
    /// - Parameter id: device and technology identifier
    func providerConnectionWasRefused(_ id: ProviderId) {
        if let provider = providersStore[id] {
            provider.controller?.linkDidCancelConnect(cause: .refused, removing: false)
        }
    }

    /// Notifies that a device is disconnecting.
    ///
    /// - Parameter id: device and technology identifier
    func providerWillDisconnect(_ id: ProviderId? = nil) {
        if let provider = id != nil ? providersStore[id!] : activeProvider {
            provider.active = false
        }
    }

    /// Notifies that the list of known providers has changed.
    ///
    /// - Parameter providers: new list of known providers
    func knownProvidersDidChange(_ providers: [ProviderInfo]) {
        providersMinus(ids: providers.map { $0.providerId }).forEach { $0.known = false }
        providers.forEach { getOrCreateProvider($0)?.known = true }
    }
}
