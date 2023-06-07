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

/// Removable user storage component controller for UserStorage feature based devices
class RemovableUserStorageController: UserStorageController {
    /// Removable user storage component
    private var removableUserStorage: RemovableUserStorageCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        removableUserStorage = RemovableUserStorageCore(store: deviceController.device.peripheralStore, backend: self)
        userStorage = removableUserStorage!
    }

    override func didConnect() {
        removableUserStorage.publish()
    }

    override func didDisconnect() {
        removableUserStorage.unpublish()
        super.didDisconnect()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureUserStorageUid {
            ArsdkFeatureUserStorage.decode(command, callback: self)
        }
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureUserStorageV2Uid {
            ArsdkFeatureUserStorageV2.decode(command, callback: self)
        }
    }
}

/// User storage decode callback implementation
extension RemovableUserStorageController: ArsdkFeatureUserStorageCallback {

    func onInfo(name: String, capacity: UInt64) {
        removableUserStorage.update(name: name, capacity: Int64(capacity)).notifyUpdated()
    }

    func onMonitor(availableBytes: UInt64) {
        removableUserStorage.update(availableSpace: Int64(availableBytes)).notifyUpdated()
    }

    func onState(
        physicalState: ArsdkFeatureUserStoragePhyState, fileSystemState: ArsdkFeatureUserStorageFsState,
        attributeBitField: UInt, monitorEnabled: UInt, monitorPeriod: UInt) {

        isEncrypted(isEncrypted: ArsdkFeatureUserStorageAttributeBitField.isSet(.encrypted,
                                                                                inBitField: attributeBitField))

        state(physicalState: physicalState, fileSystemState: fileSystemState,
              attributeBitField: attributeBitField, monitorEnabled: monitorEnabled, monitorPeriod: monitorPeriod)

        userStorage.notifyUpdated()
    }

    func onFormatResult(result: ArsdkFeatureUserStorageFormattingResult) {
        formatResult(result: result)
    }

    func onCapabilities(supportedFeaturesBitField: UInt) {
        capabilities(supportedFeaturesBitField: supportedFeaturesBitField)
    }

    func onSupportedFormattingTypes(supportedTypesBitField: UInt) {
        supportedFormattingTypes(supportedTypesBitField: supportedTypesBitField)
    }

    func onFormatProgress(step: ArsdkFeatureUserStorageFormattingStep, percentage: UInt) {
        formatProgress(step: step, percentage: percentage)
    }

    func onDecryption(result: ArsdkFeatureUserStoragePasswordResult) {
        decryption(result: result)
    }

    func onSdcardUuid(uuid: String) {
        sdcardUuid(uuid: uuid)
    }
}

/// user storage decode callback implementation
extension RemovableUserStorageController: ArsdkFeatureUserStorageV2Callback {

    func onCapabilities(storageId: UInt, supportedFeaturesBitField: UInt,
        storageType: ArsdkFeatureUserStorageV2StorageType, listFlagsBitField: UInt) {
        if storageType == .removableStorage {
            userStorageType = .removableStorage
            userStorageId = storageId
            capabilities(supportedFeaturesBitField: supportedFeaturesBitField)
        }
    }

    func onInfo(storageId: UInt, name: String, capacity: UInt64, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            removableUserStorage.update(name: name, capacity: Int64(capacity)).notifyUpdated()
        }
    }

    func onMonitor(storageId: UInt, availableBytes: UInt64, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            removableUserStorage.update(availableSpace: Int64(availableBytes)).notifyUpdated()
        }
    }

    func onState(storageId: UInt, physicalState: ArsdkFeatureUserStorageV2PhyState,
        fileSystemState: ArsdkFeatureUserStorageV2FsState, attributeBitField: UInt, monitorEnabled: UInt,
        monitorPeriod: UInt, fstype: String, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            isEncrypted(isEncrypted: ArsdkFeatureUserStorageV2AttributeBitField.isSet(.encrypted,
                                                                                    inBitField: attributeBitField))
            hasCheckError(hasCheckError: ArsdkFeatureUserStorageV2AttributeBitField.isSet(.checkError,
                                                                                      inBitField: attributeBitField))
            state(physicalState: physicalState, fileSystemState: fileSystemState,
                attributeBitField: attributeBitField, monitorEnabled: monitorEnabled,
                monitorPeriod: monitorPeriod)
            userStorage.notifyUpdated()
        }
    }

    func onFormatResult(storageId: UInt, result: ArsdkFeatureUserStorageV2FormattingResult, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            formatResult(result: result)
        }
    }

    func onSupportedFormattingTypes(storageId: UInt, supportedTypesBitField: UInt, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            supportedFormattingTypes(supportedTypesBitField: supportedTypesBitField)
        }
    }

    func onFormatProgress(storageId: UInt, step: ArsdkFeatureUserStorageV2FormattingStep, percentage: UInt,
        listFlagsBitField: UInt) {
        if userStorageId == storageId {
            formatProgress(step: step, percentage: percentage)
        }
    }

    func onStorageUuid(storageId: UInt, uuid: String, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            sdcardUuid(uuid: uuid)
        }
      }

    func onDecryption(storageId: UInt, result: ArsdkFeatureUserStorageV2PasswordResult, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            decryption(result: result)
        }
    }
}
