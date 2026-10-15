// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkStorageEventDecoder`.
protocol ArsdkStorageEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Storage_Event.Monitor` event.
    ///
    /// - Parameter monitor: event to process
    func onMonitor(_ monitor: Arsdk_Storage_Event.Monitor)

    /// Processes a `Arsdk_Storage_Event.StorageList` event.
    ///
    /// - Parameter storageList: event to process
    func onStorageList(_ storageList: Arsdk_Storage_Event.StorageList)

    /// Processes a `Arsdk_Storage_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Storage_Event.State)

    /// Processes a `Arsdk_Storage_Event.FormattingProgress` event.
    ///
    /// - Parameter formattingProgress: event to process
    func onFormattingProgress(_ formattingProgress: Arsdk_Storage_Event.FormattingProgress)

    /// Processes a `Arsdk_Storage_Event.FormattingResult` event.
    ///
    /// - Parameter formattingResult: event to process
    func onFormattingResult(_ formattingResult: Arsdk_Storage_Event.FormattingResult)

    /// Processes a `Arsdk_Storage_Event.UnlockResult` event.
    ///
    /// - Parameter unlockResult: event to process
    func onUnlockResult(_ unlockResult: Arsdk_Storage_Event.UnlockResult)

    /// Processes a `Arsdk_Storage_Event.PassphraseResult` event.
    ///
    /// - Parameter passphraseResult: event to process
    func onPassphraseResult(_ passphraseResult: Arsdk_Storage_Event.PassphraseResult)
}

/// Decoder for arsdk.storage.Event events.
class ArsdkStorageEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.storage.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkStorageEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkStorageEventDecoderListener) {
       self.listener = listener
    }

    /// Decodes an event.
    ///
    /// - Parameter event: event to decode
    func decode(_ event: OpaquePointer) {
       if ArsdkCommand.getFeatureId(event) == kArsdkFeatureGenericUid {
            ArsdkFeatureGeneric.decode(event, callback: self)
        }
    }

    func onCustomEvtNonAck(serviceId: UInt, msgNum: UInt, payload: Data) {
        processEvent(serviceId: serviceId, payload: payload, isNonAck: true)
    }

    func onCustomEvt(serviceId: UInt, msgNum: UInt, payload: Data) {
        processEvent(serviceId: serviceId, payload: payload, isNonAck: false)
    }

    /// Processes a custom event.
    ///
    /// - Parameters:
    ///    - serviceId: service identifier
    ///    - payload: event payload
    private func processEvent(serviceId: UInt, payload: Data, isNonAck: Bool) {
        guard serviceId == ArsdkStorageEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Storage_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkStorageEventDecoder event \(event)")
            }
            switch event.id {
            case .monitor(let event):
                listener?.onMonitor(event)
            case .storageList(let event):
                listener?.onStorageList(event)
            case .state(let event):
                listener?.onState(event)
            case .formattingProgress(let event):
                listener?.onFormattingProgress(event)
            case .formattingResult(let event):
                listener?.onFormattingResult(event)
            case .unlockResult(let event):
                listener?.onUnlockResult(event)
            case .passphraseResult(let event):
                listener?.onPassphraseResult(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Storage_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Storage_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .monitor: return 1
        case .storageList: return 16
        case .state: return 17
        case .formattingProgress: return 18
        case .formattingResult: return 19
        case .unlockResult: return 20
        case .passphraseResult: return 21
        }
    }
}

/// Decoder for arsdk.storage.Command commands.
class ArsdkStorageCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.storage.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Storage_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkStorageCommandEncoder command \(command)")
        var message = Arsdk_Storage_Command()
        message.id = command
        if let payload = try? message.serializedData() {
            return ArsdkFeatureGeneric.customCmdEncoder(serviceId: serviceId,
                                                        msgNum: UInt(command.number),
                                                        payload: payload)
        }
        return nil
    }
}

/// Extension to get command field number.
extension Arsdk_Storage_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .listStorages: return 16
        case .getState: return 17
        case .format: return 18
        case .startMonitoring: return 19
        case .stopMonitoring: return 20
        case .unlock: return 21
        case .setPassphrase: return 22
        }
    }
}
extension Arsdk_Storage_Command.GetState {
    static var idFieldNumber: Int32 { 1 }
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_Command.Format {
    static var idFieldNumber: Int32 { 1 }
    static var labelFieldNumber: Int32 { 2 }
    static var typeFieldNumber: Int32 { 3 }
    static var passphraseFieldNumber: Int32 { 4 }
    static var encryptionFieldNumber: Int32 { 5 }
}
extension Arsdk_Storage_Command.StartMonitoring {
    static var idFieldNumber: Int32 { 1 }
    static var periodFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_Command.StopMonitoring {
    static var idFieldNumber: Int32 { 1 }
}
extension Arsdk_Storage_Command.Unlock {
    static var idFieldNumber: Int32 { 1 }
    static var passphraseFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_Command.SetPassphrase {
    static var idFieldNumber: Int32 { 1 }
    static var newPassphraseFieldNumber: Int32 { 2 }
    static var currentPassphraseFieldNumber: Int32 { 3 }
}
extension Arsdk_Storage_Command {
    static var listStoragesFieldNumber: Int32 { 16 }
    static var getStateFieldNumber: Int32 { 17 }
    static var formatFieldNumber: Int32 { 18 }
    static var startMonitoringFieldNumber: Int32 { 19 }
    static var stopMonitoringFieldNumber: Int32 { 20 }
    static var unlockFieldNumber: Int32 { 21 }
    static var setPassphraseFieldNumber: Int32 { 22 }
}
extension Arsdk_Storage_Event.Monitor {
    static var idFieldNumber: Int32 { 1 }
    static var availableSpaceFieldNumber: Int32 { 3 }
}
extension Arsdk_Storage_Event.StorageList {
    static var storagesFieldNumber: Int32 { 1 }
}
extension Arsdk_Storage_Event.State {
    static var idFieldNumber: Int32 { 1 }
    static var defaultCapabilitiesFieldNumber: Int32 { 2 }
    static var storageInfoFieldNumber: Int32 { 3 }
    static var storageStateFieldNumber: Int32 { 4 }
    static var storageUuidFieldNumber: Int32 { 5 }
}
extension Arsdk_Storage_Event.FormattingProgress {
    static var idFieldNumber: Int32 { 1 }
    static var stepFieldNumber: Int32 { 2 }
    static var percentageFieldNumber: Int32 { 3 }
}
extension Arsdk_Storage_Event.FormattingResult {
    static var idFieldNumber: Int32 { 1 }
    static var statusFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_Event.UnlockResult {
    static var idFieldNumber: Int32 { 1 }
    static var statusFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_Event.PassphraseResult {
    static var idFieldNumber: Int32 { 1 }
    static var errorFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_Event {
    static var monitorFieldNumber: Int32 { 1 }
    static var storageListFieldNumber: Int32 { 16 }
    static var stateFieldNumber: Int32 { 17 }
    static var formattingProgressFieldNumber: Int32 { 18 }
    static var formattingResultFieldNumber: Int32 { 19 }
    static var unlockResultFieldNumber: Int32 { 20 }
    static var passphraseResultFieldNumber: Int32 { 21 }
}
extension Arsdk_Storage_Storage {
    static var idFieldNumber: Int32 { 1 }
    static var typeFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_Capabilities {
    static var supportedFeaturesFieldNumber: Int32 { 1 }
    static var supportedErasingTypesFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_StorageInfo {
    static var nameFieldNumber: Int32 { 1 }
    static var capacityFieldNumber: Int32 { 2 }
}
extension Arsdk_Storage_StorageState {
    static var physicalStateFieldNumber: Int32 { 1 }
    static var fileSystemStateFieldNumber: Int32 { 2 }
    static var fileSystemTypeFieldNumber: Int32 { 3 }
    static var attributesFieldNumber: Int32 { 4 }
    static var isMonitoringEnabledFieldNumber: Int32 { 5 }
    static var monitoringPeriodFieldNumber: Int32 { 6 }
    static var encryptionStateFieldNumber: Int32 { 7 }
}
extension Arsdk_Storage_StorageUUID {
    static var uuidFieldNumber: Int32 { 1 }
}
extension Arsdk_Storage_EncryptionState {
    static var encryptionTypeFieldNumber: Int32 { 1 }
    static var isLockedFieldNumber: Int32 { 2 }
    static var hasPassphraseFieldNumber: Int32 { 3 }
    static var canAddPassphraseFieldNumber: Int32 { 4 }
    static var canChangePassphraseFieldNumber: Int32 { 5 }
    static var canRemovePassphraseFieldNumber: Int32 { 6 }
}
