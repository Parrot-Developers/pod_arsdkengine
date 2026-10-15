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

/// Internal user storage component controller for UserStorage feature based devices
class InternalUserStorageController: UserStorageController {
    /// Internal user storage component
    private var internalUserStorage: InternalUserStorageCore!

    /// Constructor
    ///
    /// - Parameter deviceController: device controller owning this component controller (weak)
    override init(deviceController: DeviceController) {
        super.init(deviceController: deviceController)
        arsdkStorageProtoEncoder = ArsdkStorageEventDecoder(listener: self)
        internalUserStorage = InternalUserStorageCore(store: deviceController.device.peripheralStore, backend: self)
        userStorage = internalUserStorage!
    }

    override func willConnect() {
        _ = sendListStorageCommand()
    }

    override func didConnect() {
        if userStorageSupport == .legacyV2 {
            internalUserStorage.publish()
        }
    }

    override func didDisconnect() {
        internalUserStorage.unpublish()
        super.didDisconnect()
    }

    /// A command has been received
    ///
    /// - Parameter command: received command
    override func didReceiveCommand(_ command: OpaquePointer) {
        super.didReceiveCommand(command)
        if ArsdkCommand.getFeatureId(command) == kArsdkFeatureUserStorageV2Uid {
            ArsdkFeatureUserStorageV2.decode(command, callback: self)
        }
    }
}

/// Internal user storage decode callback implementation
extension InternalUserStorageController: ArsdkFeatureUserStorageV2Callback {

    func onCapabilities(storageId: UInt, supportedFeaturesBitField: UInt,
                        storageType: ArsdkFeatureUserStorageV2StorageType, listFlagsBitField: UInt) {
        if storageType == .internalStorage {
            userStorageSupport = .legacyV2
            userStorageId = storageId
            capabilities(supportedFeaturesBitField: supportedFeaturesBitField)
        }
    }

    func onInfo(storageId: UInt, name: String, capacity: UInt64, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            internalUserStorage.update(name: name, capacity: Int64(capacity)).notifyUpdated()
        }
    }

    func onMonitor(storageId: UInt, availableBytes: UInt64, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            internalUserStorage.update(availableSpace: Int64(availableBytes)).notifyUpdated()
        }
    }

    func onState(storageId: UInt, physicalState: ArsdkFeatureUserStorageV2PhyState,
                 fileSystemState: ArsdkFeatureUserStorageV2FsState, attributeBitField: UInt, monitorEnabled: UInt,
                 monitorPeriod: UInt, fstype: String, listFlagsBitField: UInt) {
        if userStorageId == storageId {
            isEncrypted(isEncrypted: ArsdkFeatureUserStorageV2AttributeBitField
                .isSet(.encrypted, inBitField: attributeBitField))
            hasCheckError(hasCheckError: ArsdkFeatureUserStorageV2AttributeBitField
                .isSet(.checkError, inBitField: attributeBitField))
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

    func onFormatProgress(storageId: UInt, step: ArsdkFeatureUserStorageV2FormattingStep,
                          percentage: UInt, listFlagsBitField: UInt) {
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

/// Internal user storage protobuf decode callback implementation
extension InternalUserStorageController: ArsdkStorageEventDecoderListener {
    func onStorageList(_ storageList: Arsdk_Storage_Event.StorageList) {
        userStorageSupport = .proto

        for storage in storageList.storages where storage.type == .internal {
            userStorageId = UInt(storage.id)
            _ = sendGetStateCommand(storageId: storage.id)
            return
        }
    }

    func onState(_ state: Arsdk_Storage_Event.State) {
        guard UInt(state.id) == userStorageId else {
            return
        }

        if state.hasDefaultCapabilities {
            forceCapabilities()
            supportedFormattingTypes(supportedTypes: state.defaultCapabilities.supportedErasingTypes)
        }

        if state.hasStorageInfo {
            internalUserStorage.update(name: state.storageInfo.name, capacity: Int64(state.storageInfo.capacity))
        }

        if state.hasStorageState {
            isEncrypted(isEncrypted: state.storageState.attributes.contains(.encrypted))
            hasCheckError(hasCheckError: state.storageState.attributes.contains(.checkError))
            if state.storageState.hasEncryptionState {
                let encryptionState = state.storageState.encryptionState
                if let encryptionType = UserStorageEncryptionType(fromArsdk: encryptionState.encryptionType) {
                    internalUserStorage.update(encryptionState: UserStorageEncryptionState(
                        type: encryptionType,
                        isLocked: encryptionState.isLocked,
                        hasPassphrase: encryptionState.hasPassphrase_p,
                        canAddPassphrase: encryptionState.canAddPassphrase,
                        canChangePassphrase: encryptionState.canChangePassphrase,
                        canRemovePassphrase: encryptionState.canRemovePassphrase))
                }
            }
            update(physicalState: state.storageState.physicalState, fileSystemState: state.storageState.fileSystemState,
                  attributes: state.storageState.attributes, monitorEnabled: state.storageState.isMonitoringEnabled,
                  monitorPeriod: Int(state.storageState.monitoringPeriod))
        }

        if state.hasStorageUuid {
            sdcardUuid(uuid: state.storageUuid.uuid)
        }
        internalUserStorage.publish()
    }

    func onFormattingProgress(_ formattingProgress: Arsdk_Storage_Event.FormattingProgress) {
        if UInt(formattingProgress.id) == userStorageId {
            formatProgress(step: formattingProgress.step, percentage: UInt(formattingProgress.percentage))
        }
    }

    func onMonitor(_ monitor: Arsdk_Storage_Event.Monitor) {
        if UInt(monitor.id) == userStorageId {
            internalUserStorage.update(availableSpace: Int64(monitor.availableSpace)).notifyUpdated()
        }
    }

    func onFormattingResult(_ formattingResult: Arsdk_Storage_Event.FormattingResult) {
        if UInt(formattingResult.id) == userStorageId {
            formattingStatus(status: formattingResult.status)
        }
    }

    func onUnlockResult(_ unlockResult: Arsdk_Storage_Event.UnlockResult) {
        if UInt(unlockResult.id) == userStorageId {
            unlock(result: unlockResult.status)
        }
    }

    func onPassphraseResult(_ passphraseResult: Arsdk_Storage_Event.PassphraseResult) {
        if UInt(passphraseResult.id) == userStorageId {
            internalUserStorage.update(
                passphraseStatus: UserStoragePassphraseStatus(fromArsdk: passphraseResult.error)).notifyUpdated()
            internalUserStorage.update(passphraseStatus: nil).notifyUpdated()
        }
    }
}
