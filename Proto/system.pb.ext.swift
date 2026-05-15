// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkSystemEventDecoder`.
protocol ArsdkSystemEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_System_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_System_Event.State)
}

/// Decoder for arsdk.system.Event events.
class ArsdkSystemEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.system.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkSystemEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkSystemEventDecoderListener) {
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
        guard serviceId == ArsdkSystemEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_System_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkSystemEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_System_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_System_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.system.Command commands.
class ArsdkSystemCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.system.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_System_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkSystemCommandEncoder command \(command)")
        var message = Arsdk_System_Command()
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
extension Arsdk_System_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setProductName: return 17
        }
    }
}
extension Arsdk_System_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_System_Command.SetProductName {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_System_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setProductNameFieldNumber: Int32 { 17 }
}
extension Arsdk_System_Event.State {
    static var productNameFieldNumber: Int32 { 2 }
}
extension Arsdk_System_Event {
    static var stateFieldNumber: Int32 { 16 }
}
