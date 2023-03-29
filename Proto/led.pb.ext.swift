// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkLedEventDecoder`.
protocol ArsdkLedEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Led_Event.Luminosity` event.
    ///
    /// - Parameter luminosity: event to process
    func onLuminosity(_ luminosity: Arsdk_Led_Event.Luminosity)
}

/// Decoder for arsdk.led.Event events.
class ArsdkLedEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.led.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkLedEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkLedEventDecoderListener) {
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
        guard serviceId == ArsdkLedEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Led_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkLedEventDecoder event \(event)")
            }
            switch event.id {
            case .luminosity(let event):
                listener?.onLuminosity(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Led_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Led_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .luminosity: return 16
        }
    }
}

/// Decoder for arsdk.led.Command commands.
class ArsdkLedCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.led.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Led_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkLedCommandEncoder command \(command)")
        var message = Arsdk_Led_Command()
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
extension Arsdk_Led_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getLuminosity: return 16
        case .setLuminosity: return 17
        }
    }
}
extension Arsdk_Led_Command.SetLuminosity {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Led_Command {
    static var getLuminosityFieldNumber: Int32 { 16 }
    static var setLuminosityFieldNumber: Int32 { 17 }
}
extension Arsdk_Led_Event.Luminosity {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Led_Event {
    static var luminosityFieldNumber: Int32 { 16 }
}
