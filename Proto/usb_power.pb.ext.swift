// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkUsbpowerEventDecoder`.
protocol ArsdkUsbpowerEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Usbpower_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Usbpower_Event.State)
}

/// Decoder for arsdk.usbpower.Event events.
class ArsdkUsbpowerEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.usbpower.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkUsbpowerEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkUsbpowerEventDecoderListener) {
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
        guard serviceId == ArsdkUsbpowerEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Usbpower_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkUsbpowerEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Usbpower_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Usbpower_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.usbpower.Command commands.
class ArsdkUsbpowerCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.usbpower.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Usbpower_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkUsbpowerCommandEncoder command \(command)")
        var message = Arsdk_Usbpower_Command()
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
extension Arsdk_Usbpower_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .power: return 17
        }
    }
}
extension Arsdk_Usbpower_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Usbpower_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var powerFieldNumber: Int32 { 17 }
}
extension Arsdk_Usbpower_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var usbPowersFieldNumber: Int32 { 2 }
}
extension Arsdk_Usbpower_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Usbpower_Capabilities {
    static var supportedTypesFieldNumber: Int32 { 1 }
}
extension Arsdk_Usbpower_Powers {
    static var powersFieldNumber: Int32 { 1 }
}
extension Arsdk_Usbpower_Power {
    static var connectorTypeFieldNumber: Int32 { 1 }
    static var enabledFieldNumber: Int32 { 2 }
}
