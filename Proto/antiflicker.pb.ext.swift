// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkAntiflickerEventDecoder`.
protocol ArsdkAntiflickerEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Antiflicker_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Antiflicker_Event.State)
}

/// Decoder for arsdk.antiflicker.Event events.
class ArsdkAntiflickerEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.antiflicker.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkAntiflickerEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkAntiflickerEventDecoderListener) {
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
        guard serviceId == ArsdkAntiflickerEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Antiflicker_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkAntiflickerEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Antiflicker_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Antiflicker_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.antiflicker.Command commands.
class ArsdkAntiflickerCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.antiflicker.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Antiflicker_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkAntiflickerCommandEncoder command \(command)")
        var message = Arsdk_Antiflicker_Command()
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
extension Arsdk_Antiflicker_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setMode: return 17
        }
    }
}
extension Arsdk_Antiflicker_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Antiflicker_Command.SetMode {
    static var modeFieldNumber: Int32 { 1 }
}
extension Arsdk_Antiflicker_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setModeFieldNumber: Int32 { 17 }
}
extension Arsdk_Antiflicker_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var disabledFieldNumber: Int32 { 2 }
    static var fixedFieldNumber: Int32 { 3 }
    static var automaticFieldNumber: Int32 { 4 }
}
extension Arsdk_Antiflicker_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Antiflicker_Capabilities {
    static var supportedModesFieldNumber: Int32 { 1 }
}
