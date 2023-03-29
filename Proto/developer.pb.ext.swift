// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkDeveloperEventDecoder`.
protocol ArsdkDeveloperEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Developer_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Developer_Event.State)
}

/// Decoder for arsdk.developer.Event events.
class ArsdkDeveloperEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.developer.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkDeveloperEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkDeveloperEventDecoderListener) {
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
        guard serviceId == ArsdkDeveloperEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Developer_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkDeveloperEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Developer_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Developer_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.developer.Command commands.
class ArsdkDeveloperCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.developer.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Developer_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkDeveloperCommandEncoder command \(command)")
        var message = Arsdk_Developer_Command()
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
extension Arsdk_Developer_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .enableShell: return 17
        case .disableShell: return 18
        case .airSdkLog: return 19
        }
    }
}
extension Arsdk_Developer_Command.EnableShell {
    static var publicKeyFieldNumber: Int32 { 1 }
}
extension Arsdk_Developer_Command.AirSdkLog {
    static var enableFieldNumber: Int32 { 1 }
}
extension Arsdk_Developer_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var enableShellFieldNumber: Int32 { 17 }
    static var disableShellFieldNumber: Int32 { 18 }
    static var airSdkLogFieldNumber: Int32 { 19 }
}
extension Arsdk_Developer_Event.State {
    static var shellFieldNumber: Int32 { 1 }
    static var airsdklogFieldNumber: Int32 { 2 }
}
extension Arsdk_Developer_Event.AirSdkLog {
    static var enabledFieldNumber: Int32 { 1 }
}
extension Arsdk_Developer_Event.Shell {
    static var enabledFieldNumber: Int32 { 1 }
    static var publicKeyFieldNumber: Int32 { 2 }
}
extension Arsdk_Developer_Event {
    static var stateFieldNumber: Int32 { 16 }
}
