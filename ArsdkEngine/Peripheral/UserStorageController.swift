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
import SwiftProtobuf

/// User storage component controller for UserStorage feature based devices
class UserStorageController: DeviceComponentController {
    /// User storage component
    public var userStorage: UserStorageCore!

    /// `true` if formatting is allowed in state `.ready`.
    public var formatWhenReadyAllowed = false

    /// `true` if formatting result event is supported by the drone.
    public var formatResultEvtSupported = false

    /// `true` if encryption event is supported by the drone.
    private var encryptionSupported = false

    /// `true` when a format request was sent and a formatting result event is expected.
    public var waitingFormatResult = false

    /// Latest state received from device.
    public var latestState: UserStorageFileSystemState?

    /// State received during formatting, that will be notified after formatting result.
    public var pendingState: UserStorageFileSystemState?

    /// `true` if formatting type is supported by the drone.
    public var formattingTypeSupported = false

    /// ID of user storage
    public var userStorageId: UInt?

    /// User storage support and protocol selection for the current connection.
    public var userStorageSupport: UserStorageSupport?

    /// Decoder for storage events.
    public var arsdkStorageProtoEncoder: ArsdkStorageEventDecoder!

    /// User storage support.
    public enum UserStorageSupport: String, CustomStringConvertible, CaseIterable {
        /// User storage type is unsupported
        case legacyV1
        /// User storage type is supported
        case legacyV2
        /// User storage is supported via `Storage` proto messages
        case proto
        /// Debug description.
        public var description: String { rawValue }
    }

    override func didConnect() {
        userStorage.publish()
    }

    override func didDisconnect() {
        userStorage.unpublish()
        userStorageSupport = .legacyV1
        waitingFormatResult = false
        latestState = nil
        pendingState = nil
        formattingTypeSupported = false
        userStorageId = nil
        userStorage.update(encryptionState: nil)
        userStorage.update(passphraseStatus: nil)
    }

    override func didReceiveCommand(_ command: OpaquePointer) {
        arsdkStorageProtoEncoder.decode(command)
    }

    /// Updates state and formatting capability according to this state and notify changes
    ///
    /// - Parameter state: new state to set
    private func updateState(_ state: UserStorageFileSystemState) {
        userStorage.update(fileSystemState: state)
            .update(canFormat: (state == .needFormat || (formatWhenReadyAllowed && state == .ready)
                                || state == .passwordNeeded)).notifyUpdated()
    }

    public func updateFormattingType(_ formattingType: Set<FormattingType>) {
        userStorage.update(supportedFormattingTypes: formattingType).notifyUpdated()
    }

    private func updateEncryptionSupported(_ isEncryptionSupported: Bool) {
        userStorage.update(isEncryptionSupported: isEncryptionSupported).notifyUpdated()
    }

    private func updateFormatProgress(formattingStep: FormattingStep, formattingProgress: Int) {
        userStorage.update(formattingStep: formattingStep, formattingProgress: formattingProgress).notifyUpdated()
    }
}

/// User storage backend implementation
extension UserStorageController: UserStorageBackend {
    public func format(formattingType: FormattingType, newMediaName: String?) -> Bool {
        var commandSent = false
        if userStorageSupport == . proto {
            if let userStorageId {
                commandSent = sendFormatCommand(label: newMediaName ?? "", formattingType: formattingType,
                                                encryption: false)
            }
        } else {
            if !formattingTypeSupported {
                if userStorageSupport == .legacyV2 {
                    if let userStorageId {
                        commandSent = sendCommand(ArsdkFeatureUserStorageV2.formatEncoder(storageId: userStorageId,
                                                                                          label: newMediaName ?? ""))
                    }
                } else {
                    commandSent = sendCommand(ArsdkFeatureUserStorage.formatEncoder(label: newMediaName ?? ""))
                }
            } else {
                switch formattingType {
                case .quick:
                    if userStorageSupport == .legacyV2 {
                        if let userStorageId {
                            commandSent = sendCommand(ArsdkFeatureUserStorageV2.formatWithTypeEncoder(
                                storageId: userStorageId, label: newMediaName ?? "", type: .quick))
                        }
                    } else {
                        commandSent = sendCommand(ArsdkFeatureUserStorage.formatWithTypeEncoder(
                            label: newMediaName ?? "", type: .quick))
                    }
                case .full:
                    if userStorageSupport == .legacyV2 {
                        if let userStorageId {
                            commandSent = sendCommand(ArsdkFeatureUserStorageV2.formatWithTypeEncoder(
                                storageId: userStorageId, label: newMediaName ?? "", type: .full))
                        }
                    } else {
                        commandSent = sendCommand(ArsdkFeatureUserStorage.formatWithTypeEncoder(
                            label: newMediaName ?? "", type: .full))
                    }
                }
            }
        }
        if commandSent && formatResultEvtSupported {
            waitingFormatResult = true
            updateState(.formatting)
        }
        return commandSent
    }

    func formatWithEncryption(password: String?, formattingType: FormattingType, newMediaName: String?) -> Bool {
        var commandSent = false
        if userStorageSupport == . proto {
            if let userStorageId {
                commandSent = sendFormatCommand(label: newMediaName ?? "", formattingType: formattingType,
                                                password: password, encryption: true)
            }
        } else {
            if encryptionSupported {
                switch formattingType {
                case .quick:
                    if userStorageSupport == .legacyV2 {
                        if let userStorageId {
                            commandSent = sendCommand(ArsdkFeatureUserStorageV2
                                .formatWithEncryptionEncoder(storageId: userStorageId,
                                                             label: newMediaName ?? "",
                                                             password: password ?? "", type: .quick))
                        }
                    } else {
                        commandSent = sendCommand(ArsdkFeatureUserStorage
                            .formatWithEncryptionEncoder(label: newMediaName ?? "",
                                                         password: password ?? "", type: .quick))
                    }
                case .full:
                    if userStorageSupport == .legacyV2 {
                        if let userStorageId {
                            commandSent = sendCommand(ArsdkFeatureUserStorageV2
                                .formatWithEncryptionEncoder(storageId: userStorageId,
                                                             label: newMediaName ?? "",
                                                             password: password ?? "", type: .full))
                        }
                    } else {
                        commandSent = sendCommand(ArsdkFeatureUserStorage
                            .formatWithEncryptionEncoder(label: newMediaName ?? "",
                                                         password: password ?? "", type: .full))
                    }
                }
            }
        }
        if commandSent && formatResultEvtSupported {
            waitingFormatResult = true
            updateState(.formatting)
        }
        return commandSent
    }

    func sendPassword(password: String, usage: PasswordUsage) -> Bool {
        if userStorageSupport == .proto {
            if let userStorageId {
                return sendUnlock(passphrase: password)
            }
        } else {
            switch usage {
            case .record:
                if userStorageSupport == .legacyV2 {
                    if let userStorageId {
                        return sendCommand(ArsdkFeatureUserStorageV2.encryptionPasswordEncoder(storageId: userStorageId,
                                                                                               password: password,
                                                                                               type: .record))
                    }
                } else {
                    return sendCommand(ArsdkFeatureUserStorage.encryptionPasswordEncoder(password: password,
                                                                                         type: .record))
                }
            case .usb:
                if userStorageSupport == .legacyV2 {
                    if let userStorageId {
                        return sendCommand(ArsdkFeatureUserStorageV2.encryptionPasswordEncoder(
                            storageId: userStorageId, password: password, type: .usb))
                    }
                } else {
                    return sendCommand(ArsdkFeatureUserStorage.encryptionPasswordEncoder(password: password,
                                                                                         type: .usb))
                }
            }
        }
        return false
    }

    func setPassphrase(newPassphrase: String?, currentPassphrase: String?) -> Bool {
        if userStorageSupport == .proto, let userStorageId {
            return setPassphraseCommand(passphrase: newPassphrase, currentPassphrase: currentPassphrase)
        } else {
            return false
        }
    }
}

extension UserStorageController {

    func state(physicalState: ArsdkFeatureUserStoragePhyState,
               fileSystemState: ArsdkFeatureUserStorageFsState,
               attributeBitField: UInt, monitorEnabled: UInt, monitorPeriod: UInt) {

        var newPhysicalState = UserStoragePhysicalState.noMedia
        var newFileSystemState = UserStorageFileSystemState.error

        switch physicalState {
        case .undetected:
            newPhysicalState = .noMedia
        case .tooSmall:
            newPhysicalState = .mediaTooSmall
        case .tooSlow:
            newPhysicalState = .mediaTooSlow
        case .usbMassStorage:
            newPhysicalState = .usbMassStorage
        case .available:
            newPhysicalState = .available
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown physicalState, skipping this event.")
            return
        }

        userStorage.update(physicalState: newPhysicalState)

        switch fileSystemState {
        case .unknown:
            newFileSystemState = .mounting
        case .formatNeeded:
            newFileSystemState = .needFormat
        case .formatting:
            newFileSystemState = .formatting
        case .ready:
            newFileSystemState = .ready
        case .error:
            newFileSystemState = .error
        case .checking:
            newFileSystemState = .checking
        case .passwordNeeded:
            newFileSystemState = .passwordNeeded
        case .externalAccessOk:
            newFileSystemState = .externalAccessOk
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown fileSystemState, skipping this event.")
            return
        }

        if !formatResultEvtSupported && latestState == .formatting {
            // format result when the drone does not support the format result event
            if newFileSystemState == .ready {
                updateState(.formattingSucceeded)
            } else if newFileSystemState == .needFormat || newFileSystemState == .error {
                updateState(.formattingFailed)
            }
        }

        if waitingFormatResult && newFileSystemState != .formatting {
            // new state will be notified after reception of formatting result
            pendingState = newFileSystemState
        } else {
            updateState(newFileSystemState)
        }
        latestState = newFileSystemState
        if newFileSystemState == .ready && monitorEnabled == 0 {
            _ = sendCommand(ArsdkFeatureUserStorage.startMonitoringEncoder(period: 0))
        } else if newFileSystemState != .ready && monitorEnabled == 1 {
            _ = sendCommand(ArsdkFeatureUserStorage.stopMonitoringEncoder())
        }
    }

    func sdcardUuid(uuid: String) {
        userStorage.update(uuid: uuid).notifyUpdated()
    }

    func isEncrypted(isEncrypted: Bool) {
        userStorage.update(isEncrypted: isEncrypted)
    }

    func hasCheckError(hasCheckError: Bool) {
        userStorage.update(hasCheckError: hasCheckError)
    }

    func decryption(result: ArsdkFeatureUserStoragePasswordResult) {
        switch result {
        case .wrongPassword:
            updateState(.decryptionWrongPassword)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .wrongUsage:
            updateState(.decryptionWrongUsage)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .success:
            updateState(.decryptionSucceeded)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
    }

    func decryption(result: ArsdkFeatureUserStorageV2PasswordResult) {
        switch result {
        case .wrongPassword:
            updateState(.decryptionWrongPassword)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .wrongUsage:
            updateState(.decryptionWrongUsage)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .success:
            updateState(.decryptionSucceeded)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
    }

    func state(physicalState: ArsdkFeatureUserStorageV2PhyState, fileSystemState: ArsdkFeatureUserStorageV2FsState,
               attributeBitField: UInt, monitorEnabled: UInt, monitorPeriod: UInt) {

        var newPhysicalState = UserStoragePhysicalState.noMedia
        var newFileSystemState = UserStorageFileSystemState.error

        switch physicalState {
        case .undetected:
            newPhysicalState = .noMedia
        case .tooSmall:
            newPhysicalState = .mediaTooSmall
        case .tooSlow:
            newPhysicalState = .mediaTooSlow
        case .usbMassStorage:
            newPhysicalState = .usbMassStorage
        case .available:
            newPhysicalState = .available
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown physicalState, skipping this event.")
            return
        }

        userStorage.update(physicalState: newPhysicalState)

        switch fileSystemState {
        case .unknown:
            newFileSystemState = .mounting
        case .formatNeeded:
            newFileSystemState = .needFormat
        case .formatting:
            newFileSystemState = .formatting
        case .ready:
            newFileSystemState = .ready
        case .error:
            newFileSystemState = .error
        case .checking:
            newFileSystemState = .checking
        case .passwordNeeded:
            newFileSystemState = .passwordNeeded
        case .externalAccessOk:
            newFileSystemState = .externalAccessOk
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown fileSystemState, skipping this event.")
            return
        }

        if !formatResultEvtSupported && latestState == .formatting {
            // format result when the drone does not support the format result event
            if newFileSystemState == .ready {
                updateState(.formattingSucceeded)
            } else if newFileSystemState == .needFormat || newFileSystemState == .error {
                updateState(.formattingFailed)
            }
        }

        if waitingFormatResult && newFileSystemState != .formatting {
            // new state will be notified after reception of formatting result
            pendingState = newFileSystemState
        } else {
            updateState(newFileSystemState)
        }
        latestState = newFileSystemState
        if newFileSystemState == .ready && monitorEnabled == 0 {
            _ = sendCommand(ArsdkFeatureUserStorageV2.startMonitoringEncoder(storageId: userStorageId!, period: 0))
        } else if newFileSystemState != .ready && monitorEnabled == 1 {
            _ = sendCommand(ArsdkFeatureUserStorageV2.stopMonitoringEncoder(storageId: userStorageId!))
        }
    }

    func formatResult(result: ArsdkFeatureUserStorageFormattingResult) {
        switch result {
        case .error:
            updateState(.formattingFailed)
        case .denied:
            updateState(.formattingDenied)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .success:
            updateState(.formattingSucceeded)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
        if let pendingState = pendingState {
            updateState(pendingState)
            self.pendingState = nil
        }
        waitingFormatResult = false
    }

    func formatResult(result: ArsdkFeatureUserStorageV2FormattingResult) {
        switch result {
        case .error:
            updateState(.formattingFailed)
        case .denied:
            updateState(.formattingDenied)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .success:
            updateState(.formattingSucceeded)
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
        if let pendingState = pendingState {
            updateState(pendingState)
            self.pendingState = nil
        }
        waitingFormatResult = false
    }

    func formatProgress(step: ArsdkFeatureUserStorageFormattingStep, percentage: UInt) {
        var formattingStep: FormattingStep = .partitioning
        switch step {
        case .partitioning:
            formattingStep = .partitioning
        case .clearingData:
            formattingStep = .clearingData
        case .creatingFs:
            formattingStep = .creatingFs
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
        updateFormatProgress(formattingStep: formattingStep, formattingProgress: Int(percentage))
    }

    func formatProgress(step: ArsdkFeatureUserStorageV2FormattingStep, percentage: UInt) {
        var formattingStep: FormattingStep = .partitioning
        switch step {
        case .partitioning:
            formattingStep = .partitioning
        case .clearingData:
            formattingStep = .clearingData
        case .creatingFs:
            formattingStep = .creatingFs
        case .sdkCoreUnknown:
            fallthrough
        @unknown default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
        updateFormatProgress(formattingStep: formattingStep, formattingProgress: Int(percentage))
    }

    func supportedFormattingTypes(supportedTypesBitField: UInt) {
        formattingTypeSupported = true
        var availableFormattingType: Set<FormattingType> = []
        if ArsdkFeatureUserStorageFormattingTypeBitField.isSet(.quick, inBitField: supportedTypesBitField) {
            availableFormattingType.insert(.quick)
        }
        if ArsdkFeatureUserStorageFormattingTypeBitField.isSet(.full, inBitField: supportedTypesBitField) {
            availableFormattingType.insert(.full)
        }
        updateFormattingType(availableFormattingType)
    }

    func capabilities(supportedFeaturesBitField: UInt) {
        formatResultEvtSupported = ArsdkFeatureUserStorageFeatureBitField.isSet(.formatResultEvtSupported,
                                                                                inBitField: supportedFeaturesBitField)
        formatWhenReadyAllowed = ArsdkFeatureUserStorageFeatureBitField.isSet(.formatWhenReadyAllowed,
                                                                              inBitField: supportedFeaturesBitField)
        encryptionSupported = ArsdkFeatureUserStorageFeatureBitField.isSet(.encryptionSupported,
                                                                           inBitField: supportedFeaturesBitField)
        updateEncryptionSupported(encryptionSupported)
        if let latestState = latestState {
            updateState(latestState)
        }
    }
}

// User storage controller for protobuf updates.
extension UserStorageController {

    func update(physicalState: Arsdk_Storage_PhysicalState, fileSystemState: Arsdk_Storage_FileSystemState,
               attributes: [Arsdk_Storage_Attribute], monitorEnabled: Bool, monitorPeriod: Int) {

        let newPhysicalState = UserStoragePhysicalState(fromArsdk: physicalState) ?? .noMedia
        let newFileSystemState = UserStorageFileSystemState(fromArsdk: fileSystemState) ?? .error
        userStorage.update(physicalState: newPhysicalState)

        if !formatResultEvtSupported && latestState == .formatting {
            // format result when the drone does not support the format result event
            if newFileSystemState == .ready {
                updateState(.formattingSucceeded)
            } else if newFileSystemState == .needFormat || newFileSystemState == .error {
                updateState(.formattingFailed)
            }
        }

        if waitingFormatResult && newFileSystemState != .formatting {
            // new state will be notified after reception of formatting result
            pendingState = newFileSystemState
        } else {
            updateState(newFileSystemState)
        }
        latestState = newFileSystemState
        if newFileSystemState == .ready && !monitorEnabled {
            var startMonitoring = Arsdk_Storage_Command.StartMonitoring()
            startMonitoring.id = UInt32(userStorageId!)
            _ = sendStorageCommand(.startMonitoring(startMonitoring))
        } else if newFileSystemState != .ready && monitorEnabled {
            var stopMonitoring = Arsdk_Storage_Command.StopMonitoring()
            stopMonitoring.id = UInt32(userStorageId!)
            _ = sendStorageCommand(.stopMonitoring(stopMonitoring))
        }
    }

    func formatProgress(step: Arsdk_Storage_FormattingStep, percentage: UInt) {
        if let formattingStep =  FormattingStep(fromArsdk: step) {
            updateFormatProgress(formattingStep: formattingStep, formattingProgress: Int(percentage))
        } else {
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
    }

    func formattingStatus(status: Arsdk_Storage_FormattingStatus) {
        switch status {
        case .error:
            updateState(.formattingFailed)
        case .denied:
            updateState(.formattingDenied)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .success:
            updateState(.formattingSucceeded)
        default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
        if let pendingState = pendingState {
            updateState(pendingState)
            self.pendingState = nil
        }
        waitingFormatResult = false
    }

    func unlock(result: Arsdk_Storage_UnlockStatus) {
        switch result {
        case .resultWrongPassphrase:
            updateState(.decryptionWrongPassword)
            if let lastState = latestState {
                // since in that case the device will not send another state,
                // restore latest state received before formatting
                updateState(lastState)
            }
        case .resultSuccess:
            updateState(.decryptionSucceeded)
        default:
            ULog.w(.tag, "Unknown result, skipping this event.")
        }
    }

    func forceCapabilities() {
        formatResultEvtSupported = true
        formatWhenReadyAllowed = true
        encryptionSupported = true
        updateEncryptionSupported(true)
        if let latestState = latestState {
            updateState(latestState)
        }
    }

    func supportedFormattingTypes(supportedTypes: [Arsdk_Storage_ErasingType]) {
        updateFormattingType(Set(supportedTypes.compactMap({ formattingType in
            return FormattingType(fromArsdk: formattingType)
        })))
    }
}

extension UserStorageController {

    /// Sends get state command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendGetStateCommand(storageId: UInt32) -> Bool {
        var getState = Arsdk_Storage_Command.GetState()
        getState.id = UInt32(userStorageId!)
        getState.includeDefaultCapabilities = true
        return sendStorageCommand(.getState(getState))
    }

    /// Sends a list storage command.
    ///
    /// - Returns: `true` if the command has been sent
    func sendListStorageCommand() -> Bool {
        return sendStorageCommand(.listStorages(Arsdk_Storage_Command.ListStorages()))
    }

    /// Sends a format command.
    ///
    /// - Parameters:
    ///    - label: the label
    ///    - formattingType: the formatting type
    ///    - password: the password
    ///    - encryption: Whether or not to encrypt.
    /// - Returns: `true` if the command has been sent
    func sendFormatCommand(label: String, formattingType: FormattingType, password: String? = nil,
                           encryption: Bool) -> Bool {
        var format = Arsdk_Storage_Command.Format()
        format.id = UInt32(userStorageId!)
        format.type = formattingType.arsdkValue!
        format.label = label
        if let password {
            format.passphrase = Google_Protobuf_StringValue(password)
        }
        format.encryption = encryption
        return sendStorageCommand(.format(format))

    }

    /// Sends an unlock command
    ///
    /// - Parameters:
    ///    - passphrase: the passphrase
    /// - Returns: `true` if the command has been sent
    func sendUnlock(passphrase: String) -> Bool {
        var unlock = Arsdk_Storage_Command.Unlock()
        unlock.id = UInt32(userStorageId!)
        unlock.passphrase = passphrase
        return sendStorageCommand(.unlock(unlock))
    }

    /// Sends a set passphrase command.
    ///
    /// - Parameters:
    ///    - passphrase: the new passphrase
    ///    - currentPassphrase: the current passphrase
    /// - Returns: `true` if the command has been sent
    func setPassphraseCommand(passphrase: String?, currentPassphrase: String?) -> Bool {
        var setPassphrase = Arsdk_Storage_Command.SetPassphrase()
        setPassphrase.id = UInt32(userStorageId!)
        setPassphrase.newPassphrase = passphrase ?? ""
        setPassphrase.currentPassphrase = currentPassphrase ?? ""
        return sendStorageCommand(.setPassphrase(setPassphrase))
    }

    /// Sends to the drone a storage command.
    ///
    /// - Parameter command: command to send
    /// - Returns: `true` if the command has been sent
    func sendStorageCommand(_ command: Arsdk_Storage_Command.OneOf_ID) -> Bool {
        if let encoder = ArsdkStorageCommandEncoder.encoder(command) {
            return sendCommand(encoder)
        }
        return false
    }
}

/// Extension that adds conversion from/to arsdk enum.
extension FormattingStep: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<FormattingStep, Arsdk_Storage_FormattingStep>([
        .partitioning: .partitioning,
        .clearingData: .clearingData,
        .creatingFs: .creatingFileSystem
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension FormattingType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<FormattingType, Arsdk_Storage_ErasingType>([
        .full: .full,
        .quick: .quick
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension UserStoragePhysicalState: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<UserStoragePhysicalState, Arsdk_Storage_PhysicalState>([
        .available: .available,
        .mediaTooSlow: .tooSlow,
        .mediaTooSmall: .tooSmall,
        .usbMassStorage: .usbMassStorage,
        .noMedia: .undetected
    ])
}

/// Extension that adds conversion from/to arsdk enum.
extension UserStorageFileSystemState: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<UserStorageFileSystemState, Arsdk_Storage_FileSystemState>([
        .mounting: .unknown,
        .formatting: .formatting,
        .needFormat: .formatNeeded,
        .ready: .ready,
        .error: .error,
        .checking: .checking,
        .passwordNeeded: .passphraseNeeded,
        .externalAccessOk: .formatExternalAccessOk
    ])
}

extension UserStoragePassphraseStatus: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<UserStoragePassphraseStatus, Arsdk_Storage_PassphraseErrorCode>([
        .ok: .ok,
        .tooShort: .tooShort,
        .unsupportedCharacters: .unsupportedChars,
        .unsupportedOperation: .unsupportedOperation,
        .unknown: .unknown
    ])
}

extension UserStorageEncryptionType: ArsdkMappableEnum {
    static let arsdkMapper = Mapper<UserStorageEncryptionType, Arsdk_Storage_EncryptionType>([
        .none: .none,
        .legacy: .legacy,
        .secureStorageV1: .secureStorageV1
    ])
}
