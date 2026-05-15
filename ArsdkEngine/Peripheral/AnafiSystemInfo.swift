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

/// Drone system info component controller for Anafi message based drones
class AnafiSystemInfo: ArsdkSystemInfo {

    /// Decoder for system events.
    private var arsdkDecoder: ArsdkSystemEventDecoder!

    /// First part of the serial. Need to be stored in a variable because the serial is not received atomically
    var serialHigh: String? {
        didSet(newVal) {
            tryToUpdateSerial()
        }
    }
    /// Second part of the serial. Need to be stored in a variable because the serial is not received atomically
    var serialLow: String? {
        didSet(newVal) {
            tryToUpdateSerial()
        }
    }

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        backend = self
        arsdkDecoder = ArsdkSystemEventDecoder(listener: self)
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureCommonSettingsstateUid {
            ArsdkFeatureCommonSettingsstate.decode(command, callback: self)
        } else if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            arsdkDecoder.decode(command)
        }
    }

    /// Updates the serial of the systemInfo if the two parts of the serial are available
    private func tryToUpdateSerial() {
        if let serialLow = serialLow, let serialHigh = serialHigh {
            systemInfo.update(serial: serialHigh + serialLow).notifyUpdated()
            deviceStore.write(key: PersistedDataKey.serial, value: serialHigh + serialLow).commit()
            self.serialLow = nil
            self.serialHigh = nil
        }
    }

    override func createSystemInfo() {
        systemInfo = SystemInfoCore(store: deviceController.device.peripheralStore, backend: self)
    }
}

extension AnafiSystemInfo {
    /// Sends system info set product name command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendProductNameCommand(value: String) -> Bool {
        var command = Arsdk_System_Command.SetProductName()
        command.value = value
        return sendSystemCommand(.setProductName(command))
    }

    /// Sends system info get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand() -> Bool {
        var command = Arsdk_System_Command.GetState()
        command.includeDefaultCapabilities = true
        return sendSystemCommand(.getState(command))
    }

    /// Sends to the device a system command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    private func sendSystemCommand(_ command: Arsdk_System_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkSystemCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension for state processing.
extension AnafiSystemInfo: ArsdkSystemEventDecoderListener {
    func onState(_ state: Arsdk_System_Event.State) {
        if state.hasProductName {
            systemInfo.update(productName: state.productName.value).publish()
        }
    }
}

/// ArsdkSystemInfo backend implementation
extension AnafiSystemInfo: ArsdkSystemInfoBackend {
    func doSendGetState() -> Bool {
        return sendGetStateCommand()
    }

    func doSet(productName: String) -> Bool {
        return sendProductNameCommand(value: productName)
    }

    func doResetSettings() -> Bool {
        return sendCommand(ArsdkFeatureCommonSettings.resetEncoder())
    }

    func doFactoryReset() -> Bool {
        return sendCommand(ArsdkFeatureCommonFactory.resetEncoder())
    }

    func doPowerOff() -> Bool {
        return sendCommand(ArsdkFeatureCommonCommon.powerOffEncoder())
    }

    func doReboot() -> Bool {
        return sendCommand(ArsdkFeatureCommonCommon.rebootEncoder())
    }
}

/// Common settings state decode callback implementation
extension AnafiSystemInfo: ArsdkFeatureCommonSettingsstateCallback {
    func onProductVersionChanged(software: String, hardware: String) {
        systemInfo.update(hardwareVersion: hardware)
        firmwareVersionDidChange(versionStr: software)
        systemInfo.notifyUpdated()
        deviceStore.write(key: PersistedDataKey.hardwareVersion, value: hardware).commit()
    }

    func onProductSerialHighChanged(high: String) {
        serialHigh = high
    }

    func onProductSerialLowChanged(low: String) {
        serialLow = low
    }

    func onResetChanged() {
        systemInfo.resetSettingsEnded().notifyUpdated()
    }

    func onBoardIdChanged(id: String) {
        systemInfo.update(boardId: id).notifyUpdated()
        deviceStore.write(key: PersistedDataKey.boardId, value: id).commit()
    }
}
