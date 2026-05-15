// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkTrackingEventDecoder`.
protocol ArsdkTrackingEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Tracking_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Tracking_Event.State)
}

/// Decoder for arsdk.tracking.Event events.
class ArsdkTrackingEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.tracking.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkTrackingEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkTrackingEventDecoderListener) {
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
        guard serviceId == ArsdkTrackingEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Tracking_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkTrackingEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Tracking_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Tracking_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.tracking.Command commands.
class ArsdkTrackingCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.tracking.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Tracking_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkTrackingCommandEncoder command \(command)")
        var message = Arsdk_Tracking_Command()
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
extension Arsdk_Tracking_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        }
    }
}
extension Arsdk_Tracking_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Tracking_Command {
    static var getStateFieldNumber: Int32 { 16 }
}
extension Arsdk_Tracking_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var marginsFieldNumber: Int32 { 2 }
}
extension Arsdk_Tracking_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Tracking_Margins {
    static var leftFieldNumber: Int32 { 1 }
    static var rightFieldNumber: Int32 { 2 }
    static var topFieldNumber: Int32 { 3 }
    static var bottomFieldNumber: Int32 { 4 }
}
