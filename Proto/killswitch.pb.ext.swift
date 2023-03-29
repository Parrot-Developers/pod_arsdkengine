// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkKillswitchEventDecoder`.
protocol ArsdkKillswitchEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Killswitch_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Killswitch_Event.State)
}

/// Decoder for arsdk.killswitch.Event events.
class ArsdkKillswitchEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.killswitch.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkKillswitchEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkKillswitchEventDecoderListener) {
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
        guard serviceId == ArsdkKillswitchEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Killswitch_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkKillswitchEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Killswitch_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Killswitch_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.killswitch.Command commands.
class ArsdkKillswitchCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.killswitch.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Killswitch_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkKillswitchCommandEncoder command \(command)")
        var message = Arsdk_Killswitch_Command()
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
extension Arsdk_Killswitch_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setSecureMessage: return 17
        case .setMode: return 18
        case .activate: return 19
        }
    }
}
extension Arsdk_Killswitch_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Killswitch_Command.SetSecureMessage {
    static var messageFieldNumber: Int32 { 1 }
}
extension Arsdk_Killswitch_Command.SetMode {
    static var modeFieldNumber: Int32 { 1 }
}
extension Arsdk_Killswitch_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setSecureMessageFieldNumber: Int32 { 17 }
    static var setModeFieldNumber: Int32 { 18 }
    static var activateFieldNumber: Int32 { 19 }
}
extension Arsdk_Killswitch_Event.State.Behavior {
    static var modeFieldNumber: Int32 { 1 }
}
extension Arsdk_Killswitch_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var behaviorFieldNumber: Int32 { 2 }
    static var secureMessageFieldNumber: Int32 { 3 }
    static var idleFieldNumber: Int32 { 4 }
    static var activatedByFieldNumber: Int32 { 5 }
}
extension Arsdk_Killswitch_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Killswitch_Capabilities {
    static var supportedModesFieldNumber: Int32 { 1 }
}
