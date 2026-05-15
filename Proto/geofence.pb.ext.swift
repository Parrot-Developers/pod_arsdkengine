// Generated, do not edit !

import Foundation
import GroundSdk
import SwiftProtobuf

/// Listener for `ArsdkGeofenceEventDecoder`.
protocol ArsdkGeofenceEventDecoderListener: AnyObject {

    /// Processes a `Arsdk_Geofence_Event.State` event.
    ///
    /// - Parameter state: event to process
    func onState(_ state: Arsdk_Geofence_Event.State)
}

/// Decoder for arsdk.geofence.Event events.
class ArsdkGeofenceEventDecoder: NSObject, ArsdkFeatureGenericCallback {

    /// Service identifier.
    static let serviceId = "arsdk.geofence.Event".serviceId

    /// Listener notified when events are decoded.
    private weak var listener: ArsdkGeofenceEventDecoderListener?

    /// Constructor.
    ///
    /// - Parameter listener: listener notified when events are decoded
    init(listener: ArsdkGeofenceEventDecoderListener) {
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
        guard serviceId == ArsdkGeofenceEventDecoder.serviceId else {
            return
        }
        if let event = try? Arsdk_Geofence_Event(serializedData: payload) {
            if !isNonAck {
                ULog.d(ULog.cmdTag, "ArsdkGeofenceEventDecoder event \(event)")
            }
            switch event.id {
            case .state(let event):
                listener?.onState(event)
            case .none:
                ULog.w(.tag, "Unknown Arsdk_Geofence_Event, skipping this event")
            }
        }
    }
}

/// Extension to get command field number.
extension Arsdk_Geofence_Event.OneOf_ID {
    var number: Int32 {
        switch self {
        case .state: return 16
        }
    }
}

/// Decoder for arsdk.geofence.Command commands.
class ArsdkGeofenceCommandEncoder {

    /// Service identifier.
    static let serviceId = "arsdk.geofence.Command".serviceId

    /// Gets encoder for a command.
    ///
    /// - Parameter command: command to encode
    /// - Returns: command encoder, or `nil`
    static func encoder(_ command: Arsdk_Geofence_Command.OneOf_ID) -> ArsdkCommandEncoder? {
        ULog.d(.tag, "ArsdkGeofenceCommandEncoder command \(command)")
        var message = Arsdk_Geofence_Command()
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
extension Arsdk_Geofence_Command.OneOf_ID {
    var number: Int32 {
        switch self {
        case .getState: return 16
        case .setMode: return 17
        case .setMaxDistance: return 18
        case .setMaxAltitude: return 19
        }
    }
}
extension Arsdk_Geofence_Command.GetState {
    static var includeDefaultCapabilitiesFieldNumber: Int32 { 1 }
}
extension Arsdk_Geofence_Command.SetMode {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Geofence_Command.SetMaxDistance {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Geofence_Command.SetMaxAltitude {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Geofence_Command {
    static var getStateFieldNumber: Int32 { 16 }
    static var setModeFieldNumber: Int32 { 17 }
    static var setMaxDistanceFieldNumber: Int32 { 18 }
    static var setMaxAltitudeFieldNumber: Int32 { 19 }
}
extension Arsdk_Geofence_Event.State {
    static var defaultCapabilitiesFieldNumber: Int32 { 1 }
    static var isAvailableFieldNumber: Int32 { 2 }
    static var modeFieldNumber: Int32 { 3 }
    static var maxDistanceFieldNumber: Int32 { 4 }
    static var maxAltitudeFieldNumber: Int32 { 5 }
    static var centerFieldNumber: Int32 { 6 }
}
extension Arsdk_Geofence_Event {
    static var stateFieldNumber: Int32 { 16 }
}
extension Arsdk_Geofence_Capabilities {
    static var modesFieldNumber: Int32 { 1 }
    static var maxDistanceRangeFieldNumber: Int32 { 2 }
    static var maxAltitudeRangeFieldNumber: Int32 { 3 }
}
extension Arsdk_Geofence_Center {
    static var coordinatesFieldNumber: Int32 { 1 }
}
extension Arsdk_Geofence_Coordinates {
    static var latitudeFieldNumber: Int32 { 1 }
    static var longitudeFieldNumber: Int32 { 2 }
}
extension Arsdk_Geofence_ModeValue {
    static var valueFieldNumber: Int32 { 1 }
}
extension Arsdk_Geofence_FloatRange {
    static var minFieldNumber: Int32 { 1 }
    static var maxFieldNumber: Int32 { 2 }
}
