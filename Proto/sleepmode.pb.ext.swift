// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkSleepmodeEventDecoder`.
protocol ArsdkSleepmodeEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Sleepmode_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Sleepmode_Event.State)

    /// Processes a `Arsdk_Sleepmode_Event.Activation` event.
    ///
    /// - Parameter activation: event to process
    func onActivation(_ activation: Arsdk_Sleepmode_Event.Activation)
}

/// Decoder for arsdk.sleepmode.Event events.
class ArsdkSleepmodeEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.sleepmode.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkSleepmodeEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkSleepmodeEventDecoderListener) {
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
        guard serviceId == ArsdkSleepmodeEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Sleepmode_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkSleepmodeEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .activation(let event):
                listener?.onActivation(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Sleepmode_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Sleepmode_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        case .activation: return 17
        }
    }
}

/// Decoder for arsdk.sleepmode.Command commands.
class ArsdkSleepmodeCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.sleepmode.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Sleepmode_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkSleepmodeCommandEncoder command \(command)")
        var message = Arsdk_Sleepmode_Command()
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
extension Arsdk_Sleepmode_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setSecureMessage: return 17
        case .activate: return 18
        }
    }
}
extension Arsdk_Sleepmode_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Sleepmode_Command.SetSecureMessage {
    static var messageFieldNumber: Int32 { 1 }
}
extension Arsdk_Sleepmode_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setSecureMessageFieldNumber: Int32 { 17 }
    static var activateFieldNumber: Int32 { 18 }
}
extension Arsdk_Sleepmode_Event.State {
    static var secureMessageFieldNumber: Int32 { 2 }
}
extension Arsdk_Sleepmode_Event.Activation {
    static var statusFieldNumber: Int32 { 1 }
}
extension Arsdk_Sleepmode_Event {
    static var stateFieldNumber: Int32 { 16 }
    static var activationFieldNumber: Int32 { 17 }
}
