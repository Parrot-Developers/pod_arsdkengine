// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkPrivacyEventDecoder`.
protocol ArsdkPrivacyEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Privacy_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Privacy_Event.State)
}

/// Decoder for arsdk.privacy.Event events.
class ArsdkPrivacyEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.privacy.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkPrivacyEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkPrivacyEventDecoderListener) {
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

    func onCustomEvt(serviceId: UInt, msgNum: UInt, payload: Data!) {
        processEvent(serviceId: serviceId, payload: payload, isNonAck: false)
    }

    /// Processes a custom event.
    ///
    /// - Parameters:
    ///    - serviceId: service identifier
    ///    - payload: event payload
    private func processEvent(serviceId: UInt, payload: Data, isNonAck: Bool) {
        guard serviceId == ArsdkPrivacyEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Privacy_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkPrivacyEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Privacy_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Privacy_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.privacy.Command commands.
class ArsdkPrivacyCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.privacy.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Privacy_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkPrivacyCommandEncoder command \(command)")
        var message = Arsdk_Privacy_Command()
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
extension Arsdk_Privacy_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setLogMode: return 17
        }
    }
}
extension Arsdk_Privacy_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Privacy_Command.SetLogMode {
    static var logStorageFieldNumber: Int32 { 1 }
    static var logConfigPersistenceFieldNumber: Int32 { 2 }
}
extension Arsdk_Privacy_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setLogModeFieldNumber: Int32 { 17 }
}
extension Arsdk_Privacy_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var logStorageFieldNumber: Int32 { 2 }
    static var logConfigPersistenceFieldNumber: Int32 { 3 }
}
extension Arsdk_Privacy_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Privacy_Capabilities {
    static var supportedLogStorageFieldNumber: Int32 { 1 }
    static var supportedLogConfigPersistenceFieldNumber: Int32 { 2 }
}
