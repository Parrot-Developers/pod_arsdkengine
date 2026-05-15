// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkLogsyncEventDecoder`.
protocol ArsdkLogsyncEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Logsync_Node` event.
    ///
    /// - Parameter identifier: event to process
    func onIdentifier(_ identifier: Arsdk_Logsync_Node)
}

/// Decoder for arsdk.logsync.Event events.
class ArsdkLogsyncEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.logsync.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkLogsyncEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkLogsyncEventDecoderListener) {
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
        guard serviceId == ArsdkLogsyncEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Logsync_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkLogsyncEventDecoder event \(event)")
            }
            switch event.id {
            case .identifier(let event):
                listener?.onIdentifier(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Logsync_Event, skipping this event")
            }
        }
    }
}

/// Decoder for arsdk.logsync.Event commands.
class ArsdkLogsyncEventEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.logsync.Event".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Logsync_Event.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkLogsyncEventEncoder command \(command)")
        var message = Arsdk_Logsync_Event()
        message.id = command
        if let payload = try? message.serializedData() {
            return ArsdkFeatureGeneric.customEvtEncoder(serviceId: serviceId,
                                                        msgNum: UInt(command.number),
                                                        payload: payload)
        }
        return nil
    }
}

/// Extension to get command field number.
extension Arsdk_Logsync_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .identifier: return 16
        }
    }
}

/// Decoder for arsdk.logsync.Command commands.
class ArsdkLogsyncCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.logsync.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Logsync_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkLogsyncCommandEncoder command \(command)")
        var message = Arsdk_Logsync_Command()
        message.id = command
        if let payload = try? message.serializedData() {
            return ArsdkFeatureGeneric.customCmdEncoder(serviceId: serviceId,
                                                        msgNum: UInt(command.number),
                                                        payload: payload)
        }
        return nil
    }
}
/// Listener for `ArsdkLogsyncCommandDecoder`.
protocol ArsdkLogsyncCommandDecoderListener: AnyObject {

    /// Processes a `SwiftProtobuf.Google_Protobuf_Empty` event.
    ///
    /// - Parameter syncRequest: event to process
    func onSyncRequest(_ syncRequest: SwiftProtobuf.Google_Protobuf_Empty)
}

/// Decoder for arsdk.logsync.Command events.
class ArsdkLogsyncCommandDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.logsync.Command".serviceId

    /// Listener notified when commands are decoded.
    private weak var listener: ArsdkLogsyncCommandDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when commands are decoded
    init(listener: ArsdkLogsyncCommandDecoderListener) {
       self.listener = listener
    }

    /// Decodes an command.
    ///
    /// - Parameter command: command to decode
    func decode(_ command: OpaquePointer) {
       if ArsdkCommand.getFeatureId(command) == kArsdkFeatureGenericUid {
            ArsdkFeatureGeneric.decode(command, callback: self)
        }
    }

    func onCustomCmdNonAck(serviceId: UInt, msgNum: UInt, payload: Data) {
        processCommand(serviceId: serviceId, payload: payload, isNonAck: true)
    }

    func onCustomCmd(serviceId: UInt, msgNum: UInt, payload: Data) {
        processCommand(serviceId: serviceId, payload: payload, isNonAck: false)
    }

    /// Processes a custom command.
    ///
    /// - Parameters:
    ///    - serviceId: service identifier
    ///    - payload: command payload
    private func processCommand(serviceId: UInt, payload: Data, isNonAck: Bool) {
        guard serviceId == ArsdkLogsyncCommandDecoder.serviceId else {
            return
        }
        if let command = try? Arsdk_Logsync_Command(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkLogsyncCommandDecoder command \(command)")
            }
            switch command.id {
            case .syncRequest(let command):
                listener?.onSyncRequest(command)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Logsync_Command, skipping this command")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Logsync_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .syncRequest: return 16
        }
    }
}
extension Arsdk_Logsync_Command {
    static var syncRequestFieldNumber: Int32 { 16 }
}
extension Arsdk_Logsync_Node {
    static var bootIdFieldNumber: Int32 { 1 }
    static var modelFieldNumber: Int32 { 2 }
    static var roleFieldNumber: Int32 { 3 }
}
extension Arsdk_Logsync_Event {
    static var identifierFieldNumber: Int32 { 16 }
}
