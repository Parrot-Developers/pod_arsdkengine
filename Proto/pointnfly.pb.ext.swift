// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkPointnflyEventDecoder`.
protocol ArsdkPointnflyEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Pointnfly_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Pointnfly_Event.State)

    /// Processes a `Arsdk_Pointnfly_Event.Execution` event.
    ///
    /// - Parameter execution: event to process
    func onExecution(_ execution: Arsdk_Pointnfly_Event.Execution)
}

/// Decoder for arsdk.pointnfly.Event events.
class ArsdkPointnflyEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.pointnfly.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkPointnflyEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkPointnflyEventDecoderListener) {
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
        guard serviceId == ArsdkPointnflyEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Pointnfly_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkPointnflyEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .execution(let event):
                listener?.onExecution(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Pointnfly_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Pointnfly_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        case .execution: return 17
        }
    }
}

/// Decoder for arsdk.pointnfly.Command commands.
class ArsdkPointnflyCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.pointnfly.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Pointnfly_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkPointnflyCommandEncoder command \(command)")
        var message = Arsdk_Pointnfly_Command()
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
extension Arsdk_Pointnfly_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .deactivate: return 17
        case .execute: return 18
        }
    }
}
extension Arsdk_Pointnfly_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Pointnfly_Command.Execute {
    static var pointFieldNumber: Int32 { 1 }
    static var flyFieldNumber: Int32 { 2 }
}
extension Arsdk_Pointnfly_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var deactivateFieldNumber: Int32 { 17 }
    static var executeFieldNumber: Int32 { 18 }
}
extension Arsdk_Pointnfly_Point {
    static var gimbalControlModeFieldNumber: Int32 { 1 }
    static var latitudeFieldNumber: Int32 { 2 }
    static var longitudeFieldNumber: Int32 { 3 }
    static var altitudeFieldNumber: Int32 { 4 }
}
extension Arsdk_Pointnfly_Fly {
    static var gimbalControlModeFieldNumber: Int32 { 1 }
    static var latitudeFieldNumber: Int32 { 2 }
    static var longitudeFieldNumber: Int32 { 3 }
    static var altitudeFieldNumber: Int32 { 4 }
    static var currentFieldNumber: Int32 { 5 }
    static var toTargetBeforeFieldNumber: Int32 { 6 }
    static var customBeforeFieldNumber: Int32 { 7 }
    static var customDuringFieldNumber: Int32 { 8 }
    static var maxHorizontalSpeedFieldNumber: Int32 { 9 }
    static var maxVerticalSpeedFieldNumber: Int32 { 10 }
    static var maxYawRotationSpeedFieldNumber: Int32 { 11 }
}
extension Arsdk_Pointnfly_Event.State {
    static var unavailableFieldNumber: Int32 { 2 }
    static var idleFieldNumber: Int32 { 3 }
    static var activeFieldNumber: Int32 { 4 }
}
extension Arsdk_Pointnfly_Event.Execution {
    static var statusFieldNumber: Int32 { 1 }
}
extension Arsdk_Pointnfly_Event {
    static var stateFieldNumber: Int32 { 16 }
    static var executionFieldNumber: Int32 { 17 }
}
extension Arsdk_Pointnfly_State.Unavailable {
    static var reasonsFieldNumber: Int32 { 1 }
}
extension Arsdk_Pointnfly_State.Active {
    static var pointFieldNumber: Int32 { 1 }
    static var flyFieldNumber: Int32 { 2 }
}
