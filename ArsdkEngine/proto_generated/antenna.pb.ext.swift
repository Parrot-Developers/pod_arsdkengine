// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkAntennaEventDecoder`.
protocol ArsdkAntennaEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Antenna_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Antenna_Event.State)
}

/// Decoder for arsdk.antenna.Event events.
class ArsdkAntennaEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.antenna.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkAntennaEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkAntennaEventDecoderListener) {
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
        guard serviceId == ArsdkAntennaEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Antenna_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkAntennaEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Antenna_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Antenna_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.antenna.Command commands.
class ArsdkAntennaCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.antenna.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Antenna_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkAntennaCommandEncoder command \(command)")
        var message = Arsdk_Antenna_Command()
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
extension Arsdk_Antenna_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setAntennaType: return 17
        }
    }
}
extension Arsdk_Antenna_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Antenna_Command.SetAntennaType {
    static var typeFieldNumber: Int32 { 1 }
}
extension Arsdk_Antenna_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setAntennaTypeFieldNumber: Int32 { 17 }
}
extension Arsdk_Antenna_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var antennaTypeFieldNumber: Int32 { 2 }
}
extension Arsdk_Antenna_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Antenna_Capabilities {
    static var supportedAntennaTypesFieldNumber: Int32 { 1 }
}
