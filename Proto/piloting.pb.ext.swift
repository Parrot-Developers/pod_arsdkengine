// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkPilotingEventDecoder`.
protocol ArsdkPilotingEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Piloting_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Piloting_Event.State)

    /// Processes a `Arsdk_Piloting_Event.Capabilities` event.
    ///
    /// - Parameter capabilities: event to process
    func onCapabilities(_ capabilities: Arsdk_Piloting_Event.Capabilities)
}

/// Decoder for arsdk.piloting.Event events.
class ArsdkPilotingEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.piloting.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkPilotingEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkPilotingEventDecoderListener) {
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
        guard serviceId == ArsdkPilotingEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Piloting_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkPilotingEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .capabilities(let event):
                listener?.onCapabilities(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Piloting_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Piloting_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        case .capabilities: return 17
        }
    }
}

/// Decoder for arsdk.piloting.Command commands.
class ArsdkPilotingCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.piloting.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Piloting_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkPilotingCommandEncoder command \(command)")
        var message = Arsdk_Piloting_Command()
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
extension Arsdk_Piloting_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .getCapabilities: return 17
        case .setSpeedMode: return 18
        case .setTakeoffHoveringAltitude: return 19
        case .setPreferredAttiMode: return 20
        case .startFlightMode: return 21
        case .setAssistanceMode: return 22
        }
    }
}
extension Arsdk_Piloting_Command.SetSpeedMode {
    static var speedModeFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_Command.SetTakeoffHoveringAltitude {
    static var altitudeFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_Command.StartFlightMode {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_Command.SetAssistanceMode {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var getCapabilitiesFieldNumber: Int32 { 17 }
    static var setSpeedModeFieldNumber: Int32 { 18 }
    static var setTakeoffHoveringAltitudeFieldNumber: Int32 { 19 }
    static var setPreferredAttiModeFieldNumber: Int32 { 20 }
    static var startFlightModeFieldNumber: Int32 { 21 }
    static var setAssistanceModeFieldNumber: Int32 { 22 }
}
extension Arsdk_Piloting_Event.State {
    static var speedModeFieldNumber: Int32 { 1 }
    static var takeoffHoveringAltitudeFieldNumber: Int32 { 2 }
    static var preferredAttiModeFieldNumber: Int32 { 3 }
    static var currentAttiModeFieldNumber: Int32 { 4 }
    static var assistanceModeFieldNumber: Int32 { 5 }
    static var takeoffStateFieldNumber: Int32 { 6 }
    static var vehicleTypeFieldNumber: Int32 { 7 }
    static var vehicleModeFieldNumber: Int32 { 8 }
}
extension Arsdk_Piloting_Event.Capabilities {
    static var speedModesFieldNumber: Int32 { 1 }
    static var supportedFeaturesFieldNumber: Int32 { 2 }
    static var takeoffHoveringAltitudeRangeFieldNumber: Int32 { 3 }
    static var flightModesFieldNumber: Int32 { 4 }
    static var assistanceModesFieldNumber: Int32 { 5 }
    static var supportedVehicleModesFieldNumber: Int32 { 6 }
}
extension Arsdk_Piloting_Event {
    static var stateFieldNumber: Int32 { 16 }
    static var capabilitiesFieldNumber: Int32 { 17 }
}
extension Arsdk_Piloting_AttiMode {
    static var enabledFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_SpeedModeValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_TakeoffStateValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_AssistanceModeValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_VehicleModeValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_VehicleTypeValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Piloting_FloatRange {
    static var minFieldNumber: Int32 { 1 }
    static var maxFieldNumber: Int32 { 2 }
}
