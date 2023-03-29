// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkControllernetworkEventDecoder`.
protocol ArsdkControllernetworkEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Controllernetwork_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Controllernetwork_Event.State)
}

/// Decoder for arsdk.controllernetwork.Event events.
class ArsdkControllernetworkEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.controllernetwork.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkControllernetworkEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkControllernetworkEventDecoderListener) {
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
        guard serviceId == ArsdkControllernetworkEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Controllernetwork_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkControllernetworkEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Controllernetwork_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Controllernetwork_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.controllernetwork.Command commands.
class ArsdkControllernetworkCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.controllernetwork.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Controllernetwork_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkControllernetworkCommandEncoder command \(command)")
        var message = Arsdk_Controllernetwork_Command()
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
extension Arsdk_Controllernetwork_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        }
    }
}
extension Arsdk_Controllernetwork_Command {
    static var getStateFieldNumber: Int32 { 16 }
}
extension Arsdk_Controllernetwork_Event.State {
    static var linksStatusFieldNumber: Int32 { 4 }
}
extension Arsdk_Controllernetwork_Event {
    static var stateFieldNumber: Int32 { 16 }
}
