// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkNightvisionEventDecoder`.
protocol ArsdkNightvisionEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Nightvision_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Nightvision_Event.State)
}

/// Decoder for arsdk.nightvision.Event events.
class ArsdkNightvisionEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.nightvision.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkNightvisionEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkNightvisionEventDecoderListener) {
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
        guard serviceId == ArsdkNightvisionEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Nightvision_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkNightvisionEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Nightvision_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Nightvision_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.nightvision.Command commands.
class ArsdkNightvisionCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.nightvision.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Nightvision_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkNightvisionCommandEncoder command \(command)")
        var message = Arsdk_Nightvision_Command()
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
extension Arsdk_Nightvision_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .activate: return 17
        }
    }
}
extension Arsdk_Nightvision_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Nightvision_Command.Activate {
    static var productIdFieldNumber: Int32 { 1 }
    static var valueFieldNumber: Int32 { 2 }
}
extension Arsdk_Nightvision_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var activateFieldNumber: Int32 { 17 }
}
extension Arsdk_Nightvision_Event.State {
    static var moduleFieldNumber: Int32 { 2 }
}
extension Arsdk_Nightvision_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Nightvision_Module {
    static var infoFieldNumber: Int32 { 1 }
    static var isActivatedFieldNumber: Int32 { 2 }
}
extension Arsdk_Nightvision_ModuleInfo {
    static var productIdFieldNumber: Int32 { 1 }
    static var versionFieldNumber: Int32 { 2 }
}
