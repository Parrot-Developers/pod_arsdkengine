// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkExternalautopilotEventDecoder`.
protocol ArsdkExternalautopilotEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Externalautopilot_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Externalautopilot_Event.State)

    /// Processes a `Arsdk_Externalautopilot_Event.Log` event.
    ///
    /// - Parameter log: event to process
    func onLog(_ log: Arsdk_Externalautopilot_Event.Log)
}

/// Decoder for arsdk.externalautopilot.Event events.
class ArsdkExternalautopilotEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.externalautopilot.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkExternalautopilotEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkExternalautopilotEventDecoderListener) {
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
        guard serviceId == ArsdkExternalautopilotEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Externalautopilot_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkExternalautopilotEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .log(let event):
                listener?.onLog(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Externalautopilot_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Externalautopilot_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        case .log: return 17
        }
    }
}

/// Decoder for arsdk.externalautopilot.Command commands.
class ArsdkExternalautopilotCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.externalautopilot.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Externalautopilot_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkExternalautopilotCommandEncoder command \(command)")
        var message = Arsdk_Externalautopilot_Command()
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
extension Arsdk_Externalautopilot_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        }
    }
}
extension Arsdk_Externalautopilot_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Externalautopilot_Command {
    static var getStateFieldNumber: Int32 { 16 }
}
extension Arsdk_Externalautopilot_Event.Log {
    static var levelFieldNumber: Int32 { 1 }
    static var sourceFieldNumber: Int32 { 2 }
    static var msgFieldNumber: Int32 { 3 }
}
extension Arsdk_Externalautopilot_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var flightModeFieldNumber: Int32 { 2 }
    static var connectedFieldNumber: Int32 { 3 }
}
extension Arsdk_Externalautopilot_Event {
    static var stateFieldNumber: Int32 { 16 }
    static var logFieldNumber: Int32 { 17 }
}
