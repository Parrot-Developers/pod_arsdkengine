// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkFlightdataEventDecoder`.
protocol ArsdkFlightdataEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Flightdata_WindSpeed` event.
    ///
    /// - Parameter windSpeed: event to process
    func onWindSpeed(_ windSpeed: Arsdk_Flightdata_WindSpeed)

    /// Processes a `Arsdk_Flightdata_AirSpeed` event.
    ///
    /// - Parameter airSpeed: event to process
    func onAirSpeed(_ airSpeed: Arsdk_Flightdata_AirSpeed)

    /// Processes a `Arsdk_Flightdata_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Flightdata_Event.State)
}

/// Decoder for arsdk.flightdata.Event events.
class ArsdkFlightdataEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.flightdata.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkFlightdataEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkFlightdataEventDecoderListener) {
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
        guard serviceId == ArsdkFlightdataEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Flightdata_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkFlightdataEventDecoder event \(event)")
            }
            switch event.id {
            case .windSpeed(let event):
                listener?.onWindSpeed(event)
            case .airSpeed(let event):
                listener?.onAirSpeed(event)
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Flightdata_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Flightdata_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .windSpeed: return 1
        case .airSpeed: return 2
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.flightdata.Command commands.
class ArsdkFlightdataCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.flightdata.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Flightdata_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkFlightdataCommandEncoder command \(command)")
        var message = Arsdk_Flightdata_Command()
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
extension Arsdk_Flightdata_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        }
    }
}
extension Arsdk_Flightdata_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Flightdata_Command {
    static var getStateFieldNumber: Int32 { 16 }
}
extension Arsdk_Flightdata_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var isWindSpeedAvailableFieldNumber: Int32 { 2 }
    static var isAirSpeedAvailableFieldNumber: Int32 { 3 }
}
extension Arsdk_Flightdata_Event {
    static var windSpeedFieldNumber: Int32 { 1 }
    static var airSpeedFieldNumber: Int32 { 2 }
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Flightdata_Capabilities {
    static var supportedFeaturesFieldNumber: Int32 { 1 }
}
extension Arsdk_Flightdata_WindSpeed {
    static var northFieldNumber: Int32 { 1 }
    static var eastFieldNumber: Int32 { 2 }
}
extension Arsdk_Flightdata_AirSpeed {
    static var valueFieldNumber: Int32 { 1 }
}
