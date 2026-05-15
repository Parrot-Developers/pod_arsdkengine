// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkLoiterEventDecoder`.
protocol ArsdkLoiterEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Loiter_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Loiter_Event.State)
}

/// Decoder for arsdk.loiter.Event events.
class ArsdkLoiterEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.loiter.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkLoiterEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkLoiterEventDecoderListener) {
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
        guard serviceId == ArsdkLoiterEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Loiter_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkLoiterEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Loiter_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Loiter_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.loiter.Command commands.
class ArsdkLoiterCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.loiter.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Loiter_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkLoiterCommandEncoder command \(command)")
        var message = Arsdk_Loiter_Command()
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
extension Arsdk_Loiter_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setRadius: return 17
        case .setShape: return 18
        case .setDirection: return 19
        }
    }
}
extension Arsdk_Loiter_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Loiter_Command.SetRadius {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Loiter_Command.SetShape {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Loiter_Command.SetDirection {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Loiter_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setRadiusFieldNumber: Int32 { 17 }
    static var setShapeFieldNumber: Int32 { 18 }
    static var setDirectionFieldNumber: Int32 { 19 }
}
extension Arsdk_Loiter_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var radiusFieldNumber: Int32 { 2 }
    static var shapeFieldNumber: Int32 { 3 }
    static var directionFieldNumber: Int32 { 4 }
}
extension Arsdk_Loiter_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Loiter_Capabilities {
    static var radiusRangeFieldNumber: Int32 { 1 }
    static var shapesFieldNumber: Int32 { 2 }
    static var directionsFieldNumber: Int32 { 3 }
}
extension Arsdk_Loiter_ShapeValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Loiter_DirectionValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Loiter_DoubleRange {
    static var minFieldNumber: Int32 { 1 }
    static var maxFieldNumber: Int32 { 2 }
}
