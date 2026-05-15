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

/// Provides connection for a device.
class DeviceProvider: NSObject {

    /// GroundSdk API connector that this provider represents.
    private(set) var connector: DeviceConnectorCore

    /// Parent connection provider of this connection provider.
    /// Nil if there is no parent connection provider.
    var parent: DeviceProvider?

    /// Description.
    override var description: String {
        return "DeviceProvider [connector: \(connector), parent: \(String(describing: parent))]"
    }

    /// Constructor
    ///
    /// - Parameter connector: device connector that this provider represents
    init(connector: DeviceConnectorCore) {
        self.connector = connector
    }

    /// Connects the device managed by the given controller
    ///
    /// - Parameters:
    ///   - deviceController: device controller whose device must be connected
    ///   - parameters: custom parameters to use to connect the device
    ///   - wakeIdle: `true` to wake up the drone if it's in idle state
    ///
    /// - Returns: true if the connect operation was successfully initiated,
    func connect(deviceController: DeviceController, parameters: [DeviceConnectionParameter], wakeIdle: Bool) -> Bool {
        return false
    }

    /// Disconnects the device managed by the given controller
    ///
    /// As a provider may not support the disconnect operation, this method provides a default implementation that
    /// return false. Subclasses that need to support the disconnect operation may override this method to do so.
    ///
    /// - Parameter deviceController: device controller whose device must be disconnected
    ///
    /// - Returns: true if the disconnect operation was successfully initiated
    func disconnect(deviceController: DeviceController) -> Bool {
        return false
    }

    /// Forgets the device managed by the given controller.
    ///
    /// As a provider may not support the forget operation, this method provides a default implementation that
    /// does nothing. Subclasses that need to support the forget operation may override this method to do so.
    ///
    /// - Parameter deviceController: device controller whose device must be forgotten
    func forget(deviceController: DeviceController) {
    }

    /// Notifies that some conditions that control data synchronization allowance have changed.
    ///
    /// This method allows proxy device providers to know when data sync allowance conditions concerning
    /// the device they proxy change, and take appropriate measures.
    ///
    /// Default implementation does nothing.
    ///
    /// - Parameter deviceController: device controller whose data sync allowance conditions changed
    public func dataSyncAllowanceMightHaveChanged(deviceController: DeviceController) {
    }
}
